#!/bin/bash

. ${LIBDIR}/util.sh

install_local_pkgs() {
    msg "Install local package(s):"
    printf "   %s\n" "${local_pkgs[@]}"
    echo ""
    [[ ! -d ${CHROOT_DIR}/local_pkgs ]] && mkdir ${CHROOT_DIR}/local_pkgs
    cp ${local_pkgs[@]} ${CHROOT_DIR}/local_pkgs
    chroot ${CHROOT_DIR} /bin/bash -c 'pacman -U /local_pkgs/*.zst --noconfirm' || abort "Failed to install local package(s)."
    rm ${CHROOT_DIR}/local_pkgs/*
}

rm_pkgs() {
    if [[ ! -z ${PKG_DIR} ]]; then
        msg "Remove previously built packages from [${PKG_DIR}]"
        rm ${PKG_DIR}/*.{xz,zst,sig} &>/dev/null
    fi
}

build_pkg() {
    build_dir=${CHROOT_DIR}/build
    rm -rf ${build_dir}/.[!.]*
    if [[ ${CHECKSUMS} = true ]]; then
        msg "Generate checksums for [$1]"
        cd $1
        content=$(mktemp)
        newcontent=$(mktemp)
        ls > $content
        sudo -u ${SUDO_USER} updpkgsums #generate checksums
        #check if need to be updtae also pkgver array
        if [[ $(grep 'pkgver()' PKGBUILD) ]]; then sudo -u ${SUDO_USER} makepkg -od; fi 
        if [[ $(grep 'pkgver ()' PKGBUILD) ]]; then sudo -u ${SUDO_USER} makepkg -od; fi
        #check source folder to prevent the unneeded download of source
        if [[ $SRC_DIR != $START_DIR ]]; then mv $SRC_DIR/* $START_DIR/$1; fi
        ls > $newcontent
        cp -r ${START_DIR}/$1 ${build_dir}
        cp -rf ${build_dir}/$1 ${START_DIR}
        rm -rf $(grep -vFxf $content $newcontent)
        rm -f $content $newcontent
        cd ..
    else cp -r $1 ${build_dir}
    fi
    cd ${build_dir}/$1
    rm -rf {pkg,src}/
    user_own

    [[ ${INSTALL} = true ]] && mp_opts='fsi' || mp_opts='fs'
    [[ ${MODULES} = true ]] && mp_opts='fsr'
    chroot ${CHROOT_DIR} sudo -iu builduser chrootbuild $1 $mp_opts
    status=$?
    [[ ${status} != 0 ]] && [[ ${check} = package ]] && abort "Building package [${1//\//}] failed."
    [[ ${INSTALL} = true ]] && chroot ${CHROOT_DIR} sudo pacman -R --noconfirm $1-debug 2>/dev/null
    cd ${CHROOT_DIR}/pkgdest
    mv *.{xz,zst,sig} ${PKG_DIR}/ 2>/dev/null
    cd ${START_DIR}
}

gpg_sign() {
    cd $1
    GPGKEY=$(get_config GPGKEY)
    if [[ ! -z ${GPGKEY} ]]; then
        sudo -u ${SUDO_USER} sign_pkgs
    else
        err "No gpg key found in makepkg config. Package cannot be signed."
    fi
}
