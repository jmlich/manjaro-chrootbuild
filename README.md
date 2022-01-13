# manjaro-chrootbuild

## included utilities:

- **chrootbuild** - Builds lists or individual packages in a chroot environment of native architecture.  
It is particularly useful for updating lists of git packages, where it compares git versions with current repo versions and updates remote package repos after building.  
When a newer `pkgver` is available, `pkgrel` will automatically be reset to `1`.  
While building lists, build logs will be written to separate log files for each package.  
Errors will be collected and a summary displayed at the end with links to the relevant log files.  
A log of built packages with timestamps is written to a file **build_log** in makepkg's `LOGDEST` if defined, or in `$USER_HOME/.chrootbuild-logs/`).
Local packages can be installed into the chroot filesystem before building.
Combined jobs of building packages and list are also possible, where built packages can be installed into the chroot filesystem before subsequent building of other packages and lists.
`$validpgpkeys` specified in a PKGBUILD will be received automatically before bulding the package.
```
Usage: chrootbuild [options]
     -b <branch> Branch to use (unstable/testing/stable-staging/stable;
                                arm-unstable/arm-testing/arm-stable)
                                default: unstable / arm-unstable)
     -c          Start with clean chroot fs
     -d          Disable colors (for better browser display)
     -D          Build additional debug package
     -f          Force unmount chroot if busy
     -g          Push changes to git when building lists
     -i <pkg>    Install local package (specify full path!)
     -k <repo>   Use custom repo (mobile/kde-unstable)
     -l <list>   List to build
     -n          Install built pkg to chroot fs (default when building lists)
     -p <pkg>    Package to build
     -r          Use custom chrootdir path
                 default: /var/lib/chrootbuild
     -s          Sign package(s)
     -u          Build pkgs only if newer than repo (lists only)
     -x          Remove previously built packages in $PKGDEST
```

**NOTE:** For multiple lists or packages repeat the respective flag. Example `sudo chrootbuild -csrl list-1 -l list-2` or `sudo chrootbuild -sp pkg-1 -p pkg-2`.

- **sign_pkgs**      - Signs all packages in the current directory with the gpg key configured for makepkg.

- **cb_monitor**     - To see the build progress of lists in realtime you can run `cb_monitor` in a separate terminal window or console.

- **prepare_chroot** - Install chroot filesystem and update with defined branch.
```
Usage: prepare_chroot [options]"
     -b <branch> Branch to use (unstable/testing/stable-staging/stable;
                                arm-unstable/arm-testing/arm-stable)
                                default: unstable / arm-unstable)
     -c          Create clean chroot filesystem
     -k <repo>   Use custom repo (kde-unstable/mobile)
     -m          Keep Chroot filesystem mounted
     -u          Unmount Chroot filesystem cleanly
```

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

### Install on Ubuntu 20.04

First you need to install **pacman**:

```
apt install git build-essential cmake libarchive-dev pkg-config libcurl4-openssl-dev libgpgme-dev libssl-dev fakeroot dh-autoreconf libarchive-tools xsltproc gawk subversion

git clone https://gitlab.manjaro.org/packages/core/pacman.git
pacver=5.2.2
contribver=1.4.0
cd pacman
wget https://sources.archlinux.org/other/pacman/pacman-$pacver.tar.gz
wget https://git.archlinux.org/pacman-contrib.git/snapshot/pacman-contrib-$contribver.tar.gz
tar -xvf pacman-$pacver.tar.gz
tar -xvf pacman-contrib-$contribver.tar.gz
cd pacman-$pacver
patch -p1 -i ../pacman-sync-first-option.patch
cd ../pacman-$pacver
./configure --prefix=/usr --sysconfdir=/etc \
  --localstatedir=/var --disable-doc \
  --with-scriptlet-shell=/usr/bin/bash \
  --with-ldconfig=/usr/bin/ldconfig
make V=1
make install
install -m644 pacman.conf.x86_64 /etc/pacman.conf
install -m644 makepkg.conf /etc/
sed -i /etc/makepkg.conf \
  -e "s|@CARCH[@]|x86_64|g" \
  -e "s|@CHOST[@]|x86_64-pc-linux-gnu|g" \
  -e "s|@CARCHFLAGS[@]|-march=x86-64|g"
install -m644 etc-pacman.d-gnupg.mount /usr/lib/systemd/system/etc-pacman.d-gnupg.mount
install -m644 pacman-init.service /usr/lib/systemd/system/pacman-init.service
cd pacman-contrib-$contribver.tar.gz
./autogen.sh
./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  --disable-doc
make
make install
```


Install **manjaro-chrootbuild**:

```
cd ..
git clone https://gitlab.manjaro.org/tools/development-tools/manjaro-chrootbuild
cd manjaro-chrootbuild
./install.sh

echo "PKGDEST = </pkg/destination>" >> /etc/makepkg.conf
echo "PACKAGER = <packages name> <packager@email>" >> /etc/makepkg.conf
echo "GPGKEY = <keyID>" >> /etc/makepkg.conf

pacman-key --init
cp /etc/chrootbuild/pacman.conf.x86_64 /etc/pacman.conf
sed -i "s/@BRANCH@/unstable/g" /etc/pacman.conf
pacman -Sy manjaro-keyring archlinux-keyring
pacman-key --populate manjaro archlinux
```
