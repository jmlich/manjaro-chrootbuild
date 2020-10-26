#!/bin/bash

confdir=/etc/manjaro-chrootbuild

_remove() {
    for f in $(ls $1/*.$2 | cut -d / -f 2); do
        echo "    ${f/.in/}"
        rm -rf /usr/$3/${f/.in/}
    done
}

echo "Removing manjaro-chrootbuild:"
_remove lib sh lib/manjaro-chrootbuild
_remove bin in bin
echo "    $confdir"
rm -rf $confdir
