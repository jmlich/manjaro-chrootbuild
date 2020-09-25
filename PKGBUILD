# Contributor: Bernhard Landauer <bernhard@manjaro.org>

pkgname=manjaro-arm-chrootbuild
pkgver=r20.gf8133f4
pkgrel=1
pkgdesc="Tools for native aarch64 chrootbuilds"
arch=('any')
url="https://gitlab.manjaro.org/manjaro-arm/applications/$pkgname"
license=('GPL3')
depends=()
makedepends=('git')
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

  _install lib sh 644 usr/lib/$pkgname
  _install bin in 755 usr/bin
}
