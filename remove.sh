#!/bin/bash

_remove() {
    for f in $(ls $1/*.$2 | cut -d / -f 2); do
        rm /usr/$3/${f/.in/}
    done
}

_remove lib sh lib/manjaro-chrootbuild
_remove bin in bin
