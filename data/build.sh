#!/bin/bash

export LC_ALL=en_US.UTF-8;
. /etc/profile;
cd /build/$1
. PKGBUILD
echo "validating keys: ${validpgpkeys[@]}"
gpg --keyserver hkp://hkps.pool.sks-keyservers.net --recv-keys ${validpgpkeys[@]}
makepkg -$2 --noconfirm 
