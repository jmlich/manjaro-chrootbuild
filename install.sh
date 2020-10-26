#!/bin/bash

_install() {
    for f in $(ls $1/*.$2 | cut -d / -f 2); do
        install -Dm$3 $1/$f $4/${f/.in/}
    done
}

_install lib sh 644 /usr/lib/manjaro-chrootbuild
_install bin in 755 /usr/bin
_install data 'conf.*' 644 /etc/manjaro-chrootbuild
