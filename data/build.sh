#!/bin/bash

export LC_ALL=en_US.UTF-8;
. /etc/profile;
cd /build/$1
. PKGBUILD
echo "validating keys: ${validpgpkeys[@]}"
gpg --recv-keys ${validpgpkeys[@]}
makepkg -$2 --noconfirm 
