# manjaro-chrootbuild

## included utilities:

- **chrootbuild** - Creates a chroot environment in `/var/lib/chrootbuild` and builds individual packages or build lists
```
Usage: chrootbuild [options]
     -b <branch> Branch to use (unstable/testing/stable-staging/stable;
                                arm-unstable/arm-testing/arm-stable)
                                default: arm-unstable)
     -c          Start with clean chroot fs
     -i <pkg>    Install local package (specify full path!)
     -l <list>   List to build
     -n          Install built pkg to chroot fs (default when building lists)
     -p <pkg>    Package to build
     -r          Remove previously built packages in $PKGDEST
     -s          Sign package(s)
```

- **sign_pkgs**   - Signs all packages in the current directory with the gpg key configured for makepkg

- **cb_monitor**  - Prints build log in realtime when executed in a separate terminal window (or console) while `chrootbuild` is running

![chrootbuild/cb_monitor](https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-chrootbuild/-/raw/build-monitor/chrootbuild_in_action.png)  
_Building a list of git packages on a PinebookPro while printing the build log with `cb_monitor` (top right)_
___
### Note:
Host package cache is used by default.  
`PKGDEST` and `GPGKEY` are read from host's `/etc/makepkg.conf` and/or (with precedence) the user's `~/.makepkg.conf`  
If `PKGDEST` isn't defined, package(s) will be moved to the current work directory.  
`<package>` names may be used with trailing slashes.  
`<list>s` must be present in the work directory as `<list>.list` together with a directory named `<list>`, containing all PKGBUILD-repos specified in `<list>.list`. Commenting list entries with `#` is supported.

#### todo:
- check options
- improve error and abort handling
- collect multiple packages and lists in arrays
