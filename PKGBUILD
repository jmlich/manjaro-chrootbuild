# Author: Bernhard Landauer <bernhard@manjaro.org>

pkgname=manjaro-chrootbuild
pkgver=r143.g249b6a7
pkgrel=2
pkgdesc="Build packages and buildlists in a chroot filesystem."
arch=('any')
url="https://gitlab.manjaro.org/tools/development-tools/$pkgname"
license=('GPL3')
makedepends=('git')
conflicts=(manjaro-arm-chrootbuild)
replaces=(manjaro-arm-chrootbuild manjaro-arm-chrootbuild-dev)
source=("git+$url.git")
sha256sums=('SKIP')

pkgver(){
  cd $pkgname
  printf "r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
cd $pkgname

  _install() {
      for f in $(ls $1/*.$2 | cut -d / -f 2); do
          install -Dm$3 $1/$f $pkgdir/$4/${f/.in/}
      done
  }

  _install lib sh 644 /usr/lib/$pkgname
  _install bin in 755 /usr/bin
  _install data 'conf.*' 644 /etc/chrootbuild

  # add sudo rights for 'gitlab-runner'
  install -d $pkgdir/etc/sudoers.d
  echo 'gitlab-runner ALL=NOPASSWD: /usr/bin/chrootbuild' > $pkgdir/etc/sudoers.d/gitlab-runner-chrootbuild
}
