#!/usr/bin/env bash

# _pecl <arg>...
#
# 1. Set php_ini to the active /etc/php/<version> directory
# 2. Take a backup of the $php_ini directory
# 3. Run "pecl <arg>..."
# 4. Restore the $php_ini directory from the backup
function _pecl() {
    local temp file status=0
    php_ini=$(php -r "echo php_ini_loaded_file();") || return
    php_extension_dir=$(php -r "echo ini_get('extension_dir');") || return
    php_ini=${php_ini%/*}
    [[ -f $php_ini/php.ini ]] ||
        lk_warn "php.ini not found" || return
    lk_mktemp_dir_with temp &&
        lk_tty_run_detail cp -a "$php_ini"/* "$temp/" || return
    file=$php_ini/conf.d/ext-${*: -1}.ini
    [[ ! -f $file ]] ||
        lk_tty_run_detail rm -f "$file" || return
    pecl "$@" || status=$?
    lk_tty_run_detail cp -af "$temp"/* "$php_ini/" || true
    return "$status"
}

function _php-with_usage() {
    cat <<EOF
Usage: $1 [php[@<ver>]...] [--] <command> [<arg>...]
EOF
}

# php-with [php[@<ver>]...] [--] <command> [<arg>...]
function php-with() {
    local versions=() command
    while [[ ${1-} == php ]] || [[ ${1-} == php@* ]]; do
        versions[${#versions[@]}]=$1
        shift
    done
    [[ ${1-} != -- ]] || shift
    (($#)) || lk_usage || return
    command=("$@")
    set -- "${versions[@]-php}"
    (($# < 2)) || local LK_NO_INPUT=Y
    while (($#)); do
        brew unlink "shivammathur/php/$1" &&
            brew link --overwrite --force "shivammathur/php/$1" || return
        "${command[@]}" &&
            { (($# == 1)) && [[ $1 == php ]] && return ||
                brew unlink "shivammathur/php/$1"; } ||
            return
        shift
    done
    brew unlink "shivammathur/php/php" &&
        brew link --overwrite --force "shivammathur/php/php"
}

# php-build-all [php[@<ver>]...]
function php-build-all() {
    if (($#)); then
        php-with "$@" -- "$FUNCNAME"
        return
    fi
    php-build-xdebug &&
        php-build-pcov &&
        php-build-memprof &&
        php-build-sqlsrv &&
        php-build-db2 ||
        return
}

function php-build-xdebug() {
    if (($#)); then
        php-with "$@" -- "$FUNCNAME"
        return
    fi
    local php_ini php_extension_dir file version source
    lk_tty_print "Building xdebug extension"
    php -r "if (PHP_VERSION_ID < 80000) { exit (1); }" || version=-3.1.6
    php -r "if (PHP_VERSION_ID >= 80400) { exit (1); }" ||
        { source=$(mktemp -d)/xdebug-master/package.xml &&
            curl -fL https://github.com/xdebug/xdebug/archive/refs/heads/master.tar.gz |
            tar -zxC "${source%/*/*}" ||
            return; }
    _pecl install -f "${source:-xdebug${version-}}" &&
        file=$php_ini/conf.d/ext-xdebug.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
;zend_extension="xdebug.so"
EOF
}

function php-build-pcov() {
    if (($#)); then
        php-with "$@" -- "$FUNCNAME"
        return
    fi
    local php_ini php_extension_dir file source include_dir
    lk_tty_print "Building pcov extension"
    php -r "if (PHP_VERSION_ID >= 80400) { exit (1); }" ||
        { source=$(mktemp -d)/pcov-develop/package.xml &&
            curl -fL https://github.com/krakjoe/pcov/archive/refs/heads/develop.tar.gz |
            tar -zxC "${source%/*/*}" &&
            curl -fL https://github.com/krakjoe/pcov/commit/7d764c7c2555e8287351961d72be3ebec4d8743f.patch |
            patch -d "${source%/*}" -p1 &&
            curl -fL https://github.com/krakjoe/pcov/compare/develop...release.diff |
            patch -d "${source%/*}" -p1 ||
            return; }
    include_dir=$(php -r "echo dirname(PHP_BINARY, 2);")/include/php/ext/pcre && {
        [[ -e "$include_dir/pcre2.h" ]] ||
            ln -sfnv /opt/homebrew/include/pcre2.h "$include_dir/pcre2.h"
    } || return
    _pecl install -f "${source:-pcov}" &&
        file=$php_ini/conf.d/ext-pcov.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
extension="pcov.so"
pcov.enabled = 0
EOF
}

function php-build-memprof() {
    lk_command_exists pecl ||
        lk_warn "pecl must be installed" || return
    if (($#)); then
        php-with "$@" -- "$FUNCNAME"
        return
    fi
    brew list judy &>/dev/null ||
        brew install judy || return
    local php_ini php_extension_dir file
    lk_tty_print "Building memprof extension"
    JUDY_DIR="$(brew --prefix judy)" \
        _pecl install -f memprof &&
        file=$php_ini/conf.d/ext-memprof.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
;extension="memprof.so"
EOF
}

function php-build-sqlsrv() {
    lk_command_exists pecl ||
        lk_warn "pecl must be installed" || return
    if (($#)); then
        php-with "$@" -- "$FUNCNAME"
        return
    fi
    brew tap | grep -Fx microsoft/mssql-release >/dev/null ||
        brew tap microsoft/mssql-release || return
    brew list msodbcsql18 mssql-tools18 &>/dev/null ||
        HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql18 mssql-tools18 || return
    local php_ini php_extension_dir file
    lk_tty_print "Building sqlsrv extension"
    CXXFLAGS="-I$(brew --prefix unixodbc)/include" \
    LDFLAGS="-L$(brew --prefix)/lib" \
        _pecl install -f sqlsrv &&
        file=$php_ini/conf.d/ext-sqlsrv.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
extension="sqlsrv.so"
EOF
}

# php-build-db2 [-p /path/to/macos64_odbc_cli.tar.gz]
#
# On x86_64, download clidriver from:
# - https://public.dhe.ibm.com/ibmdl/export/pub/software/data/db2/drivers/odbc_cli/macos64_odbc_cli.tar.gz
#
# On arm64, extract it from the dsdriver dmg via:
# - https://www.ibm.com/support/pages/download-db2-121-clients-and-drivers
function php-build-db2() { {
    lk_command_exists pecl odbcinst ||
        lk_warn "pecl and unixodbc must be installed" || return
    local clidriver_file=macos64_odbc_cli.tar.gz
    if (($# > 1)) && [[ $1 == -p ]]; then
        clidriver_file=$2
        shift 2
    fi
    if (($#)); then
        php-with "$@" -- "$FUNCNAME"
        return
    fi
    local clidriver_dir=/opt/clidriver-arm64 php_ini php_extension_dir temp _LK_FD=3
    lk_is_apple_silicon || clidriver_dir=/opt/clidriver
    [[ -d $clidriver_dir ]] || {
        lk_tty_print "Installing Db2 clidriver"
        [[ -f $clidriver_file ]] ||
            lk_warn "clidriver package not found" || return
        lk_mktemp_dir_with temp tar -zxf "$clidriver_file" &&
            sudo mkdir -p "${clidriver_dir%/*}" &&
            sudo mv "$temp/clidriver" "$clidriver_dir" &&
            sudo xattr -dr com.apple.quarantine "$clidriver_dir" || return
        lk_tty_success "Db2 clidriver installed successfully"
    }
    ! lk_confirm "Test Db2 installation?" N || (
        [[ :$PATH: == *:"$clidriver_dir/bin":* ]] ||
            export PATH=$clidriver_dir/bin:$PATH \
                DYLD_LIBRARY_PATH=$clidriver_dir/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}
        lk_tty_read "Database?" _DB PLAYSCHO &&
            lk_tty_read "Host?" _HOST 10.1.3.12 &&
            lk_tty_read "Port?" _PORT 50001 &&
            lk_tty_read "DSN?" _DSN edumatetest &&
            lk_tty_read "User?" _USER canvas &&
            lk_tty_read_silent "Password?" _PASSWD || return
        lk_tty_print "Testing connection to" "$_DB@$_HOST:$_PORT"
        lk_tty_run_detail db2cli writecfg add \
            -database "$_DB" -host "$_HOST" -port "$_PORT" || return
        lk_tty_run_detail db2cli writecfg add -dsn "$_DSN" \
            -database "$_DB" -host "$_HOST" -port "$_PORT" || return
        lk_tty_run_detail -9=XXXXXX db2cli validate -connect -dsn "$_DSN" \
            -user "$_USER" -passwd "$_PASSWD" || return
        lk_tty_pause
    ) || lk_confirm "Ignore errors and continue?" N || return
    lk_tty_print "Building ibm_db2 extension"
    IBM_DB_HOME="$clidriver_dir" \
        CFLAGS="-DODBC64" \
        _pecl install -f -D 'with-IBM_DB2="yes"' ibm_db2 &&
        lk_tty_run_detail install_name_tool \
            -change libdb2.dylib "$clidriver_dir/lib/libdb2.dylib" \
            "$php_extension_dir/ibm_db2.so" &&
        file=$php_ini/conf.d/ext-ibm_db2.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF' &&
extension="ibm_db2.so"
EOF
        odbcinst -d -u -n "Db2" -v &&
        odbcinst -d -i -n "Db2" -v -r <<EOF || return
[Db2]
Description=IBM Db2 Driver
Driver=$clidriver_dir/lib/libdb2.dylib
DontDLClose=1
FileUsage=1
EOF
    odbcinst -d -q -n "ODBC" 2>/dev/null | grep TraceFile >/dev/null ||
        odbcinst -d -i -n "ODBC" -v -r <<'EOF'
[ODBC]
Trace=Yes
TraceFile=/tmp/odbctrace.log
EOF
} 3>&2; }
