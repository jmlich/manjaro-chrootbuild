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



create_min_fs(){
    msg "Creating install root at $1"
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
}

create_chroot() {
    create_min_fs $1
    chroot_api_mount $1
    msg "Install build environment to $1"
    pacman -r $1 -Sy base-devel --noconfirm
    msg "Copy keyring"
    cp -a /etc/pacman.d/gnupg "$1/etc/pacman.d/"
    set_mirror $1
    msg "Create locale"
    printf 'en_US.UTF-8 UTF-8\n' > "$1/etc/locale.gen"
    printf 'LANG=en_US.UTF-8\n' > "$1/etc/locale.conf"
    printf 'LC_MESSAGES=C\n' >> "$1/etc/locale.conf"
    chroot $1 locale-gen
    touch "$1/.manjaro-arm-chroot"

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

    sed -e '/^MAKEFLAGS=/d' -e '/^PACKAGER=/d' -i "$1/${MP_CONF_GLOB}"
    for x in BUILDDIR=/build PKGDEST=/pkgdest SRCPKGDEST=/srcpkgdest SRCDEST=/srcdest LOGDEST=/logdest \
        "MAKEFLAGS='$MAKEFLAGS'" "PACKAGER='$PACKAGER'" "GPGKEY='$GPGKEY'"
    do
        grep -q "^$x" "$1/${MP_CONF_GLOB}" && continue
        echo "$x" >>"$1/${MP_CONF_GLOB}"
    done

    # create buildscript
    buildscript="$1/usr/bin/chrootbuild"
    {
        printf '#!/bin/bash\n\n'
        printf 'export LC_ALL=en_US.UTF-8;\n'
        printf '. /etc/profile;\n'
        printf 'sudo -iu builduser bash -c "cd /build/$1; makepkg -$2 --noconfirm";\n'
    } >"${buildscript}"
    chmod +x "${buildscript}"

    cp /etc/resolv.conf $1/etc/resolv.conf
}

update_chroot() {
    chroot_api_mount $1
    msg "Update chroot file system"
    pacman -r $1 -Syuu --noconfirm
}

# create/update chroot build environment
prepare_chroot() {
    if [ -e $1/.manjaro-arm-chroot ]; then
        if [ ${CLEAN_CHROOT} = true ]; then
            msg "Delete old chroot file system"
            rm -rf $1/*
            create_chroot $1
        else
            update_chroot $1
        fi
    else
        create_chroot $1
    fi
}
