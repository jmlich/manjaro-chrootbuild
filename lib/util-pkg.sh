#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

. ${LIBDIR}/util-output.sh

usage() {
    echo ''
    echo "Usage: ${0##*/} [options]"
    echo ''
    echo '     -b <branch> Branch to use (arm-unstable/arm-testing/arm-stable'
    echo '                                default: arm-unstable)'
    echo '     -c          Start with clean chroot fs'
    echo '     -h          This help'
#   echo '     -i <pkg>    Install pkg to chroot fs'
    echo '     -n          Install built pkg to chroot fs'
    echo '     -r          Remove previously built packages in $PKGDEST'
#   echo '     -s          Sign package'
    echo ''
    exit $1
}

get_conf() {
    echo "$(grep "^$1" "$2" | tail -1 | cut -d= -f2)"
}

get_mp_conf() {
    [[ -f ${MP_CONF_USER} ]] && CONF=$(get_conf $1 ${MP_CONF_USER})
    [[ -z ${CONF} ]] && CONF=$(get_conf $1 ${MP_CONF_GLOB})
    echo $CONF
}

get_config() {
    echo $(get_mp_conf $1)
}

get_pkg_dir() {
    PKG_DIR=$(get_config PKGDEST)
}

rm_pkgs() {
    if [ ! -z ${PKG_DIR} ]; then
        msg5 "Removing previously built packages from [${PKG_DIR}]."
        rm ${PKG_DIR}/*.pkg.tar.zst{,.sig} &>/dev/null
    fi
}

build_pkg() {
    msg "Configure mirrorlist for branch [${BRANCH}]"
    echo "Server = ${MIRROR}/${BRANCH}/\$repo/\$arch" > "${CHROOT_DIR}/etc/pacman.d/mirrorlist"
    
    cp -r $1 ${BUILD_DIR}
    chown -R ${BUILDUSER_UID}:${BUILDUSER_GID} ${BUILD_DIR}/$1
    
    [[ $INSTALL = true ]] && \
      chroot ${CHROOT_DIR} chrootbuild $1 'fsi' || \
      chroot ${CHROOT_DIR} chrootbuild $1 'fs'
      
    [[ ! -z ${PKG_DIR} ]] && mv ${CHROOT_DIR}/pkgdest/$1*.{xz,zst} ${PKG_DIR}/
}
