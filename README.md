# manjaro-arm-chrootbuild

```
Usage: chrootbuild [options] <package>
     -b <branch> Branch to use (arm-unstable/arm-testing/arm-stable
                                default: arm-unstable)
     -c          Start with clean chroot fs
     -n          Install built pkg to chroot fs
     -r          Remove previously built packages in $PKGDEST
     -s          Sign package
```

Host package cache is used by default.
PKGDEST and GPGKEY are read from host's `/etc/makepkg.con` and/or (with precendence) the user's `~/.makepkg.conf`

_TODO:_
- lock chroot while building
- error handling
- unmount when cancelled
- add option to install local pkgs to chroot fs
- add wrapper for batch build
- check min arg
