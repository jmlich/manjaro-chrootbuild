#!/bin/bash

_install() {
    for f in $(ls $1/*.$2 | cut -d / -f 2); do
        install -Dm$3 $1/$f /usr/$4/${f/.in/}
    done
}

_install lib sh 644 lib/manjaro-chrootbuild
_install bin in 755 bin

