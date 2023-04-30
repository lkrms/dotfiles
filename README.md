# lkrms/dotfiles

## Installation

```shell
git clone https://github.com/lkrms/dotfiles.git ~/.dotfiles
~/.dotfiles/bin/install
```

## Structure

### Host- and platform-specific variations

Settings are added to the following directories:

1. **[by-host]/`<hostname>`/`<appname>`**

   For host-specific settings. Short (`bamm-bamm`) and long
   (`bamm-bamm.localdomain`) hostnames are both recognised.

2. **[by-platform]/(`linux`|`macos`)/`<appname>`**

   For platform-specific settings. Only `linux` and `macos` are recognised for
   now.

3. **[by-default]/`<appname>`**

   For settings applicable to all hosts and platforms.

A mix of host-specific, platform-specific and system-independent settings can be
added for each application. The install script operates on the most specific
instance of each individual file, ignoring files with the same name in a
less-specific directory.

> `<appname>` is case-sensitive and must be unique to each application.

#### Example

```
.
├── by-host
│   └── bamm-bamm
│       └── Git               ; Applied if `hostname -s` prints "bamm-bamm"
│           ├── configure
│           └── files
│               └── ...
├── by-platform
│   ├── linux
│   │   └── Git               ; Applied if running on Linux
│   │       ├── configure
│   │       └── files
│   │           └── ...
│   └── macos
│       └── Git               ; Applied if running on macOS
│           ├── configure
│           └── files
│               └── ...
└── by-default
    └── Git                   ; Always applied
        ├── configure
        └── files
            └── ...
```

### Application settings

The installer processes files in `<appname>` directories in the following order:

1. **`configure`** (must be an executable file)

   Called by the installer. The absolute path of each applicable `<appname>`
   directory is passed as an argument, e.g. on Linux host "bamm-bamm" the
   installer would run:

   ```shell
   by-host/bamm-bamm/Git/configure \
       by-host/bamm-bamm/Git \
       by-platform/linux/Git \
       by-default/Git
   ```

   The following environment variables are passed to `configure`:

   - **`df_root`:** the absolute path of the `dotfiles` repository's top-level
     directory, e.g. `/home/lkrms/.dotfiles`.
   - **`friendly_df_root`:** a copy of `df_root` where the user's `HOME`
     directory is replaced with a literal tilde (`~`), e.g. `~/.dotfiles`.
   - **`df_dryrun`:** non-empty if the installer is running in dry-run mode,
     otherwise unset or empty.

   `configure` must exit as follows:

   | Exit code | Meaning                       | Installer should             |
   | --------- | ----------------------------- | ---------------------------- |
   | `0`       | No errors occurred            | Continue to the next step    |
   | `1`       | No errors occurred            | Skip to the next application |
   | `2`       | A non-critical error occurred | Skip to the next application |
   | >`2`      | A critical error occurred     | Exit                         |

2. **files\[/`<dir>`...\]/(`<dirname>`|`<filename>`)**

   The installer's default behaviour is to add a symbolic link to every file it
   finds in `files` at the same location relative to `$HOME`, e.g.

   ```
   ~
   ├── .config
   │   └── git
   │       └── config -> ~/.dotfiles/by-default/Git/files/.config/git/config
   └── .dotfiles
       └── by-default
           └── Git
               └── files
                   └── .config
                       └── git
                           └── config       ; This is the target
   ```

   But if a directory has a `<dirname>.symlink` sidecar file, a symbolic link to
   the *directory* is created instead, e.g.

   ```
   ~
   ├── .config
   │   └── git -> ~/.dotfiles/by-default/Git/files/.config/git/
   └── .dotfiles
      └── by-default
         └── Git
               └── files
                  └── .config
                     ├── git                ; Now this is the target
                     │   └── config
                     └── git.symlink        ; Because this file exists
   ```

   The content of a sidecar file is not specified.


[by-host]: by-host
[by-platform]: by-platform
[by-default]: by-default
