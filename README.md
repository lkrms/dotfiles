# lkrms/dotfiles

## Installation

```shell
git clone https://github.com/lkrms/dotfiles.git ~/.dotfiles
~/.dotfiles/bin/install
```

Or, to see what would happen without actually changing anything:

```shell
~/.dotfiles/bin/install --check
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
│           └── files
│               └── ...
├── by-platform
│   ├── linux
│   │   └── Git               ; Applied if running on Linux
│   │       ├── target
│   │       └── files
│   │           └── ...
│   └── macos
│       └── Git               ; Applied if running on macOS
│           ├── target
│           └── files
│               └── ...
└── by-default
    └── Git                   ; Always applied
        ├── configure
        ├── apply
        └── files
            └── ...
```

### Application settings

The installer processes files in `<appname>` directories in the following order.

1. **`target`** *(must be an executable file if present)*

   Provide a `target` script if symbolic links to the application's dotfiles
   should be created in a location other than the user's home directory.

   The script should print an absolute path without making any changes to the
   filesystem. The installer creates missing directories as needed.

   See [Writing scripts] for more information.

2. **`configure`** *(must be an executable file if present)*

   Provide a `configure` script to perform any tests or provisioning required
   before symbolic links to the application's dotfiles are created.

   See [Writing scripts] for details.

3. **files\[/`<dir>`...\]/(`<dirname>`|`<filename>`)**

   The installer's default behaviour is to create a symbolic link to every file
   it finds in `files` at the same location relative to the target path (`$HOME`
   by default), e.g.

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

   > The content of a sidecar file is not specified.

4. **`apply`** *(must be an executable file if present)*

   Provide an `apply` script to perform any provisioning tasks required after
   symbolic links to the application's dotfiles are created.

   See [Writing scripts] for more information.

## Writing scripts

### Arguments

The absolute path names of applicable `<appname>` directories are passed to
`target`, `configure` and `apply` scripts in order of precedence, e.g. on Linux
host "bamm-bamm", the installer would call `target` like this:

```shell
by-platform/linux/Git/target \
   /path/to/dotfiles/by-host/bamm-bamm/Git \
   /path/to/dotfiles/by-platform/linux/Git \
   /path/to/dotfiles/by-default/Git
```

### Environment variables

The following environment variables are passed to `target`, `configure` and
`apply`:

- **`df_root`:** the absolute path name of the `dotfiles` repository's top-level
  directory, e.g. `/home/lkrms/.dotfiles`.
- **`friendly_df_root`:** the location of the `dotfiles` repository for display
  purposes, e.g. `~/.dotfiles` (with a literal `~`).
- **`df_platform`:** either `linux` or `macos`.
- **`df_dryrun`:** non-empty if the installer is running in dry-run mode,
  otherwise unset or empty.
- **`df_target`:** the absolute path where symbolic links to the application's
  dotfiles are created.

### Exit codes

`target`, `configure` and `apply` must return one of the following exit codes.

| Exit code | Meaning                       | Installer should             |
| --------- | ----------------------------- | ---------------------------- |
| `0`       | No errors occurred            | Continue to the next step    |
| `1`       | No errors occurred            | Skip to the next application |
| `2`       | A non-critical error occurred | Skip to the next application |
| >`2`      | A critical error occurred     | Exit                         |


[by-host]: by-host
[by-platform]: by-platform
[by-default]: by-default
[Writing scripts]: #writing-scripts
