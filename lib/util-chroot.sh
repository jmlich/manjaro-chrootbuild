#!/bin/bash

get_pkg_dir() {
    PKG_DIR=$(get_mp_conf PKGDEST)
    [[ -z ${PKG_DIR} ]] && PKG_DIR=${START_DIR}
}

get_src_dir() {
    SRC_DIR=$(get_mp_conf SRCDEST)
    [[ -z ${SRC_DIR} ]] && SRC_DIR=${START_DIR}
}

get_default_branch() {
    case ${ARCH} in
        aarch64) BRANCH="arm-unstable" ;;
        x86_64) BRANCH="unstable" ;;
    esac
}

create_min_fs(){
    msg "Create install root at [$1]"
    rm -rf $1/*
    mkdir -m 0755 -p $1/var/{cache/pacman/pkg,lib/pacman,log} $1/{dev,run,etc}
    mkdir -m 1777 -p $1/tmp
    mkdir -m 0555 -p $1/{sys,proc}
}

chroot_mount_conditional() {
    local cond=$1; shift
    if eval "$cond"; then
        mount "$@"
    fi
}

chroot_api_mount() {
    chroot_mount_conditional "! mountpoint -q '$1'" "$1" "$1" --bind &&
    mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
    mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
    mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
    mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
    mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
    mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
    mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
    mount -o bind /var/cache/pacman/pkg $1/var/cache/pacman/pkg
    touch $1/.mount
}

set_branch() {
    sed -i "/Branch =/c\Branch = $1" ${mirror_conf}
    echo "Server = ${MIRROR}/$1/\$repo/\$arch" > "${CHROOT_DIR}/etc/pacman.d/mirrorlist"
    echo $1 > ${CHROOT_DIR}/.branch
}

add_repo() {
    msg "Adding repo [$1]."
    sed -i -e "s/@REPO@/$1/" -e 's/^#//g' ${PAC_CONF}
}

conf_pacman() {
    cp ${PAC_CONF_TPL} ${PAC_CONF}
    sed -i "s/@BRANCH@/$BRANCH/g; s|@MIRROR@|$MIRROR|g" ${PAC_CONF}
    if [ ! -z $custom_repo ]; then
        if [ $custom_repo = mobile ]; then
            if [ ! $ARCH = aarch64 ]; then
                err "Repo 'mobile' is not available for this architecture and will be skipped."
            else
                add_repo $custom_repo
            fi
        else
            add_repo $custom_repo
        fi
    fi
}

update_chroot() {
    [[ ! -e $1/.mount ]] && chroot_api_mount $1 && touch $1/.{mount,lock}
    msg "Configure branch [$2]"
    conf_pacman
    set_branch $2
    msg "Update chroot file system"
    sudo chroot $1 pacman -Syu --noconfirm || abort "Failed to update chroot."
}

create_chroot() {
    create_min_fs $1
    chroot_api_mount $1 && touch $1/.{mount,lock}
    [[ ${MULTILIB} = true ]] && touch $1/.multilib

    msg "Install build environment"
    conf_pacman
    base_pkgs=('base-devel')
    [[ ${MULTILIB} = true ]] && base_pkgs+=('multilib-devel')
    if [ ${HOST_KEYS} = false ]; then
        keyrings=('archlinux' 'manjaro')
        [[ ${ARCH} = aarch64 ]] && keyrings+=('archlinuxarm' 'manjaro-arm')
        base_pkgs+=("${keyrings[@]/%/-keyring}")
    fi
    pacman -r $1 --config ${PAC_CONF} -Syy "${base_pkgs[@]}" --noconfirm || abort "Failed to install chroot filesystem."

    echo "Backing up pacman-mirrors.conf..."
    cp /var/lib/chrootbuild/etc/pacman-mirrors.conf /var/lib/chrootbuild/etc/pacman-mirrors.conf.bak

    echo "Removing pacman-mirrors & Python packages to ensure clean chroot..."
    pacman -r $1 --config ${PAC_CONF} -Rdd pacman-mirrors python python-certifi python-chardet python-idna python-npyscreen python-requests python-urllib3 libnsl --noconfirm

    echo "Restoring pacman-mirrors.conf..."
    cp /var/lib/chrootbuild/etc/pacman-mirrors.conf.bak /var/lib/chrootbuild/etc/pacman-mirrors.conf

    if [ ${HOST_KEYS} = true ]; then
        msg "Copy keyring"
        cp -a /etc/pacman.d/gnupg "$1/etc/pacman.d/"
    else
        msg "Populate keyrings."
        chroot $1 pacman-key --init
        chroot $1 pacman-key --populate "${keyrings[@]}"
    fi
    msg "Create locale"
    printf '%s.UTF-8 UTF-8\n' C en_US de_DE > "$1/etc/locale.gen"
    echo 'LANG=C.UTF-8' > "$1/etc/locale.conf"
    printf 'LC_MESSAGES=C\n' >> "$1/etc/locale.conf"
    chroot $1 locale-gen
    cp /etc/resolv.conf $1/etc/resolv.conf
    touch "$1/.manjaro-chroot"

    # add builduser
    local install="install -o ${BUILDUSER_UID} -g ${BUILDUSER_GID}"
    local x

    printf >>"$1/etc/group"  'builduser:x:%d:\n' ${BUILDUSER_GID}
    printf >>"$1/etc/passwd" 'builduser:x:%d:%d:builduser:/build:/bin/bash\n' ${BUILDUSER_UID} ${BUILDUSER_GID}
    printf >>"$1/etc/shadow" 'builduser:!!:%d::::::\n' "$(( $(date -u +%s) / 86400 ))"

    $install -d "$1"/{build,build/.gnupg,startdir,{pkg,srcpkg,src,log}dest}

    for x in .gnupg/pubring.{kbx,gpg}; do
        [[ -r ${USER_HOME}/$x ]] || continue
        $install -m 644 "${USER_HOME}/$x" "$1/build/$x"
    done

    cat > "$1/etc/sudoers.d/builduser-pacman" <<EOF
builduser ALL = NOPASSWD: /usr/bin/pacman
EOF
    chmod 440 "$1/etc/sudoers.d/builduser-pacman"

    # adjust makepkg.conf
    GPGKEY="\"$(get_config GPGKEY)\""
    PACKAGER="\"$(get_config PACKAGER)\""
    sed -e '/^PACKAGER=/d' -i "$1/${MP_CONF_GLOB}"
    for x in BUILDDIR=/build PKGDEST=/pkgdest SRCPKGDEST=/srcpkgdest SRCDEST=/srcdest \
        'MAKEFLAGS="-j$(($(nproc)+1))"' \
        LOGDEST=/logdest "PACKAGER=${PACKAGER}" GPGKEY=${GPGKEY}
    do
        grep -q "^$x" "$1/${MP_CONF_GLOB}" && continue
        echo "$x" >>"$1/${MP_CONF_GLOB}"
    done
    options="strip docs !libtool !staticlibs emptydirs zipman purge !debug !lto"
    if [ ${DEBUG} = true ]; then
      options=$(sed 's/!debug/debug/' <<< "$options")
    fi
    if [ ${LTO} = true ]; then
      options=$(sed 's/!lto/lto/' <<< "$options")
    fi
    sed -i -e "/^OPTIONS=/c\OPTIONS=($options)" "$1/${MP_CONF_GLOB}"

    # install buildscript
    install -m755 /etc/chrootbuild/build.sh "$1/usr/bin/chrootbuild"

    update_chroot $1 ${BRANCH}
}

# create/update chroot build environment
prepare_chroot() {
    if [ -e $1/.manjaro-chroot ]; then
        if [ -e $1/.lock ]; then
            if [ ${FORCE_UNMOUNT} = true ]; then
                unmount=y
            else
                err_choice "Chroot is busy. Force unmount? [y/N]"
                    read unmount
            fi
            if [ ${unmount} = y ]; then
                cleanup "Re-mounting chroot filesystem."
            else
                exit 1
            fi
        fi
        if [ ${MULTILIB} = true ]; then
            if [ ! -e $1/.multilib ]; then
                msg "Rebuilding chroot for multilib"
                CLEAN=true
            fi
        else
            if [ -e $1/.multilib ]; then
                msg "Removing multilib chroot"
                CLEAN=true
            fi
        fi
        if [ $(cat $1/.branch) != ${BRANCH} ]; then
            msg "Rebuilding chroot for branch [${BRANCH}]"
            CLEAN=true
        fi
        if [ ${CLEAN} = true ]; then
            msg "Delete old chroot file system"
            rm -rf $1/*
            create_chroot $1
        else
            update_chroot $1 ${BRANCH}
        fi
    else
        create_chroot $1
    fi
}
