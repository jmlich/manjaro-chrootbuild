# manjaro-chrootbuild

## included utilities:

- **chrootbuild** - Builds lists or individual packages in a chroot environment.
It is particularly useful for updating lists of git packages, where it compares git versions with current repo versions and updates remote package repos after building.
When a newer `pkgver` is available, `pkgrel` will automatically be reset to `1`.  
When building lists, build logs will be written to separate log files for each package.  
Errors will be collected and a summary displayed at the end with links to the relevant log files.  
```
Usage: chrootbuild [options]
     -b <branch> Branch to use (unstable/testing/stable-staging/stable;
                                arm-unstable/arm-testing/arm-stable)
                                default: unstable / arm-unstable)
     -c          Start with clean chroot fs
     -i <pkg>    Install local package (specify full path!)
     -l <list>   List to build
     -n          Install built pkg to chroot fs (default when building lists)
     -p <pkg>    Package to build
     -r          Remove previously built packages in $PKGDEST
     -s          Sign package(s)
```

**NOTE:** For multiple lists of packages repeat the respective flag. Example `sudo chrootbuild -csrl list-1 -l list-2` or `sudo chrootbuild -sp pkg-1 -p pkg-2`.

- **sign_pkgs**   - Signs all packages in the current directory with the gpg key configured for makepkg.

- **cb_monitor**  - To see the build progress of lists in realtime you can run `cb_monitor` in a separate terminal window or console.

![chrootbuild/cb_monitor](https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-chrootbuild/-/raw/build-monitor/chrootbuild_in_action.png)  
_Building a list of git packages on a PinebookPro while printing the build log with `cb_monitor` (top right)_
___
### Note:
Host package cache is used by default.  
`PKGDEST` and `GPGKEY` are read from host's `/etc/makepkg.conf` and/or (with precedence) the user's `~/.makepkg.conf`  
If `PKGDEST` isn't defined, package(s) will be moved to the current work directory.  
`<package>` names may be used with trailing slashes.  
`<list>s` must be present in the work directory as `<list>.list` together with a directory named `<list>`, containing all PKGBUILD-repos specified in `<list>.list`.  
Commenting list entries with `#` is supported.  
To rebuild listed packages with `pkgver` identical with repo version just bump `pkgrel`.

#### todo:
- add option to build complete lists, regardless of repo version
