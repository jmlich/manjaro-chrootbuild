#!/bin/bash

_install() {
    for f in $(ls $1/*.$2 | cut -d / -f 2); do
        echo "    ${f/.in/}"
        install -Dm$3 $1/$f $4/${f/.in/}
    done
}

echo "Installing manjaro-chrootbuild"
_install lib sh 644 /usr/lib/manjaro-chrootbuild
_install bin in 755 /usr/bin
_install data 'conf.*' 644 /etc/chrootbuild
install -m644 data/build.sh /etc/chrootbuild
echo $1 >> /etc/makepkg.conf
