#!/usr/bin/env bash

# path_get <path>
function path_get() { (
    shopt -s nocasematch
    case "$1" in
    Programs) id=2 ;;                   # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/Start Menu/Programs
    Documents) id=5 ;;                  # /c/Users/<username>/Documents
    Startup) id=7 ;;                    # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup
    Recent) id=8 ;;                     # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/Recent
    SendTo) id=9 ;;                     # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/SendTo
    StartMenu) id=11 ;;                 # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/Start Menu
    Music) id=13 ;;                     # /c/Users/<username>/Music
    Videos) id=14 ;;                    # /c/Users/<username>/Videos
    Desktop) id=16 ;;                   # /c/Users/<username>/Desktop
    Fonts) id=20 ;;                     # /c/Windows/Fonts
    Templates) id=21 ;;                 # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/Templates
    CommonStartMenu) id=22 ;;           # /c/ProgramData/Microsoft/Windows/Start Menu
    CommonPrograms) id=23 ;;            # /c/ProgramData/Microsoft/Windows/Start Menu/Programs
    CommonStartup) id=24 ;;             # /c/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup
    CommonDesktop) id=25 ;;             # /c/Users/Public/Desktop
    AppData) id=26 ;;                   # /c/Users/<username>/AppData/Roaming
    LocalAppData) id=28 ;;              # /c/Users/<username>/AppData/Local
    AltStartup) id=29 ;;                # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup
    CommonAltStartup) id=30 ;;          # /c/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup
    CommonAppData) id=35 ;;             # /c/ProgramData
    Windows) id=36 ;;                   # /c/Windows
    System) id=37 ;;                    # /c/Windows/System32
    ProgramFiles) id=38 ;;              # /c/Program Files
    Pictures) id=39 ;;                  # /c/Users/<username>/Pictures
    Profile) id=40 ;;                   # /c/Users/<username>
    "System(x86)") id=41 ;;             # /c/Windows/SysWOW64
    "ProgramFiles(x86)") id=42 ;;       # /c/Program Files (x86)
    ProgramFilesCommon) id=43 ;;        # /c/Program Files/Common Files
    "ProgramFilesCommon(x86)") id=44 ;; # /c/Program Files (x86)/Common Files
    CommonTemplates) id=45 ;;           # /c/ProgramData/Microsoft/Windows/Templates
    CommonDocuments) id=46 ;;           # /c/Users/Public/Documents
    CommonAdminTools) id=47 ;;          # /c/ProgramData/Microsoft/Windows/Start Menu/Programs/Administrative Tools
    AdminTools) id=48 ;;                # /c/Users/<username>/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Administrative Tools
    CommonMusic) id=53 ;;               # /c/Users/Public/Music
    CommonPictures) id=54 ;;            # /c/Users/Public/Pictures
    CommonVideos) id=55 ;;              # /c/Users/Public/Videos
    Resources) id=56 ;;                 # /c/Windows/Resources
    *) id= ;;
    esac
    [[ -n $id ]] && cygpath -F "$id"
) || die "invalid path: $1"; }

function is_elevated() {
    if [[ -z ${df_is_elevated-} ]]; then
        net session &>/dev/null && df_is_elevated=1 || df_is_elevated=0
    fi
    ((df_is_elevated))
}

function sudo() {
    if ! is_elevated; then
        local IFS=$' \t\n'
        die "not running as administrator: $*"
    fi
    "$@"
}
