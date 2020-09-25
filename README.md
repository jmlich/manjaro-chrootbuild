# manjaro-arm-chrootbuild

```
Usage: chrootbuild [options]
     -b <branch> Branch to use (arm-unstable/arm-testing/arm-stable
                                default: arm-unstable)
     -c          Start with clean chroot fs
     -n          Install built pkg to chroot fs
     -r          Remove previously built packages in $PKGDEST
     -s          Sign package
```

TODO:
- lock chroot while building
- error handling
- unmount when cancelled
- add option to install local pkgs to chroot fs
- add wrapper for batch build
- overwrite older signature files
