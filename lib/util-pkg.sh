#!/bin/bash

. ${LIBDIR}/util.sh

MP_CONF_GLOB='/etc/makepkg.conf'
MP_CONF_USER="${USER_HOME}/.makepkg.conf"

query_conf() {
    echo "$(grep "^$1" "$2" | tail -1 | cut -d= -f2)"
}

get_mp_conf() {
    [[ -f ${MP_CONF_USER} ]] && CONF=$(query_conf $1 ${MP_CONF_USER})
    [[ -z ${CONF} ]] && CONF=$(query_conf $1 ${MP_CONF_GLOB})
    echo ${CONF//\"/}
}

get_config() {
    echo $(get_mp_conf $1)
}

install_local_pkg() {
    local pkg=${1##*/}
    msg "Install local package [$pkg]"
    cp $1 $2/pkgdest
    chroot $2 pacman -U /pkgdest/$pkg --noconfirm || abort "Failed to install local package."
    rm $2/pkgdest/$pkg
}

rm_pkgs() {
    if [ ! -z ${PKG_DIR} ]; then
        msg5 "Remove previously built packages from [${PKG_DIR}]"
        rm ${PKG_DIR}/*.{xz,zst,sig} &>/dev/null
    fi
}

sign_pkg() {
    cd $1
    GPGKEY=$(get_config GPGKEY)
    if [ ! -z ${GPGKEY} ]; then
        sudo -u ${SUDO_USER} sign_pkgs
    else
        err "No gpg key found in makepkg config. Package cannot be signed."
    fi
}

build_pkg() {
    rm -rf ${BUILD_DIR}/.[!.]*
    cp -r $1 ${BUILD_DIR}
    rm -rf ${BUILD_DIR}/$1/{pkg,src}/
    chown -R ${BUILDUSER_UID}:${BUILDUSER_GID} ${BUILD_DIR}/$1

    [[ $INSTALL = true ]] && mp_opts='fsi' || mp_opts='fs'
    chroot ${CHROOT_DIR} chrootbuild $1 $mp_opts
    status=$?
    cd ${CHROOT_DIR}/pkgdest
    [[ $sign = pkg ]] && sign_pkg .
    mv *.{xz,zst,sig} ${PKG_DIR}/ 2>/dev/null
}
