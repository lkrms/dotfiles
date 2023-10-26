#!/usr/bin/env bash

# _pecl <arg>...
#
# 1. Set php_ini to the active /etc/php/<version> directory
# 2. Take a backup of the $php_ini directory
# 3. Run "pecl <arg>..."
# 4. Restore the $php_ini directory from the backup
function _pecl() {
    ! lk_is_apple_silicon ||
        lk_warn "Apple Silicon not supported" || return
    local temp status=0
    php_ini=$(php -r "echo php_ini_loaded_file();") || return
    php_extension_dir=$(php -r "echo ini_get('extension_dir');") || return
    php_ini=${php_ini%/*}
    [[ -f $php_ini/php.ini ]] ||
        lk_warn "php.ini not found" || return
    lk_mktemp_dir_with temp &&
        lk_tty_run_detail cp -a "$php_ini"/* "$temp/" || return
    pecl "$@" || status=$?
    lk_tty_run_detail cp -af "$temp"/* "$php_ini/" || true
    return "$status"
}

# php-build-all [php[@<ver>]] ...
function php-build-all() {
    (($#)) || set -- php
    (($# < 2)) || local LK_NO_INPUT=Y
    while (($#)); do
        brew unlink "shivammathur/php/$1" &&
            brew link --overwrite --force "shivammathur/php/$1" || return
        php-build-xdebug &&
            php-build-pcov &&
            php-build-memprof &&
            php-build-sqlsrv &&
            php-build-db2 &&
            { (($# == 1)) && [[ $1 == php ]] && return ||
                brew unlink "shivammathur/php/$1"; } ||
            return
        shift
    done
    brew unlink "shivammathur/php/php" &&
        brew link --overwrite --force "shivammathur/php/php"
}

function php-build-xdebug() {
    local php_ini php_extension_dir file version=
    lk_tty_print "Building xdebug extension"
    php -r "if (PHP_VERSION_ID < 80000) { exit (1); }" || version=-3.1.6
    php -r "if (PHP_VERSION_ID >= 80300) { exit (1); }" || version=-3.3.0alpha3
    _pecl install -f "xdebug$version" &&
        file=$php_ini/conf.d/ext-xdebug.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
;zend_extension="xdebug.so"
EOF
}

function php-build-pcov() {
    local php_ini php_extension_dir file
    lk_tty_print "Building pcov extension"
    _pecl install -f pcov &&
        file=$php_ini/conf.d/ext-pcov.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
;extension="pcov.so"
pcov.enabled = 0
EOF
}

function php-build-memprof() {
    ! lk_is_apple_silicon ||
        lk_warn "Apple Silicon not supported" || return
    lk_command_exists pecl ||
        lk_warn "pecl must be installed" || return
    brew list judy &>/dev/null ||
        brew install judy || return
    local php_ini php_extension_dir file
    lk_tty_print "Building memprof extension"
    _pecl install -f memprof &&
        file=$php_ini/conf.d/ext-memprof.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
;extension="memprof.so"
EOF
}

function php-build-sqlsrv() {
    ! lk_is_apple_silicon ||
        lk_warn "Apple Silicon not supported" || return
    lk_command_exists pecl ||
        lk_warn "pecl must be installed" || return
    brew tap | grep -Fx microsoft/mssql-release >/dev/null ||
        brew tap microsoft/mssql-release || return
    brew list msodbcsql18 mssql-tools18 &>/dev/null ||
        HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql18 mssql-tools18 || return
    local php_ini php_extension_dir file
    lk_tty_print "Building sqlsrv extension"
    _pecl install -f sqlsrv &&
        file=$php_ini/conf.d/ext-sqlsrv.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF'
extension="sqlsrv.so"
EOF
}

# php-build-db2 [/path/to/macos64_odbc_cli.tar.gz]
#
# Download clidriver from:
# - https://public.dhe.ibm.com/ibmdl/export/pub/software/data/db2/drivers/odbc_cli/macos64_odbc_cli.tar.gz
function php-build-db2() { {
    ! lk_is_apple_silicon ||
        lk_warn "Apple Silicon not supported" || return
    lk_command_exists pecl odbcinst ||
        lk_warn "pecl and unixodbc must be installed" || return
    local php_ini php_extension_dir file temp _LK_FD=3
    [[ -d /opt/clidriver ]] || {
        lk_tty_print "Installing Db2 clidriver"
        local file=${1-macos64_odbc_cli.tar.gz}
        [[ -f $file ]] ||
            lk_warn "clidriver package not found" || return
        lk_mktemp_dir_with temp tar -zxf "$file" &&
            sudo mv "$temp/clidriver" /opt/ &&
            sudo xattr -dr com.apple.quarantine /opt/clidriver || return
        lk_tty_success "Db2 clidriver installed successfully"
    }
    ! lk_confirm "Test Db2 installation?" N || (
        [[ :$PATH: == *:/opt/clidriver/bin:* ]] ||
            export PATH=/opt/clidriver/bin:$PATH \
                DYLD_LIBRARY_PATH=/opt/clidriver/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}
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
    IBM_DB_HOME=/opt/clidriver \
        CFLAGS="-DODBC64" \
        _pecl install -f -D 'with-IBM_DB2="yes"' ibm_db2 &&
        lk_tty_run_detail install_name_tool \
            -change libdb2.dylib /opt/clidriver/lib/libdb2.dylib \
            "$php_extension_dir/ibm_db2.so" &&
        file=$php_ini/conf.d/ext-ibm_db2.ini &&
        lk_install -m 00644 "$file" &&
        lk_file_replace "$file" <<'EOF' &&
extension="ibm_db2.so"
EOF
        odbcinst -d -u -n "Db2" -v &&
        odbcinst -d -i -n "Db2" -v -r <<'EOF' || return
[Db2]
Description=IBM Db2 Driver
Driver=/opt/clidriver/lib/libdb2.dylib
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
