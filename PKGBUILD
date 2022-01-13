# Author: Bernhard Landauer <bernhard@manjaro.org>

pkgname=manjaro-chrootbuild
pkgver=r234.g77c74b9
pkgrel=1
pkgdesc="Build packages and buildlists in a chroot filesystem."
arch=('any')
url="https://gitlab.manjaro.org/tools/development-tools/$pkgname"
license=('GPL3')
makedepends=('git')
conflicts=(manjaro-arm-chrootbuild)
replaces=(manjaro-arm-chrootbuild manjaro-arm-chrootbuild-dev)
source=("git+$url.git")
sha256sums=('SKIP')
install=$pkgname.install

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
  install -m644 data/build.sh $pkgdir/etc/chrootbuild
}
