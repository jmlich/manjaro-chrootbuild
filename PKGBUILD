# Contributor: Bernhard Landauer <bernhard@manjaro.org>

pkgname=manjaro-chrootbuild
pkgver=r82.g949a190
pkgrel=1
pkgdesc="Build packages and buildlists in a chroot filesystem."
arch=('any')
url="https://gitlab.manjaro.org/manjaro-arm/applications/$pkgname"
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

  _install lib sh 644 var/lib/$pkgname
  _install bin in 755 usr/bin
}
