#! /bin/sh

mon=/tmp/current_build
mon_wait=/tmp/mon_msg
# term_emu=$(ps -p $(ps -p $$ -o ppid=) o args=)
build_err=()

msg_wait() {
    printf "\r   Waiting for build job ..." > $mon_wait
    echo $mon_wait > $mon
}

prepare_log() {
    LOG_DIR=$(get_config LOGDEST)
    [[ -z ${LOG_DIR} ]] && LOG_DIR=$USER_HOME/.chrootbuild-logs
    install -d ${LOG_DIR}
    log=${LOG_DIR}/build_log
}

get_ver() {
    ver=$(grep "^$1=" PKGBUILD | cut -d'=' -f2)
    echo $ver
}

reset_rel() {
    _rel=${git_ver#*-}
    if [ $_rel != 1 ]; then
        echo "[${pkg#*/}]: pkgrel $_rel > 1"
        sed -i -e "s/pkgrel=$_rel/pkgrel=1/" PKGBUILD
    fi
}

prepare_list() {
    list=$1.list.work
    cp $1.list $list
    sed -i -e '/^#/d' $list
    num="$(wc -l $list | cut -d' ' -f1)"
}

build_list() {
    msg5 "* ${1%-git}: Comparing git versions."
    cd ${START_DIR}
    printf "\n\n+++ $(date -u) - START PACKAGE UPDATE +++\n\n" >> $log

    prepare_list $1
    i=1
    for p in $(cat $list); do
        header "${1%-git}: $i/$num - $p"
        repo_ver=$(sudo pacman -Siy "${p}" 2>/dev/null | grep "Version" | cut -d":" -f2 | cut -d ' ' -f2)
        [[ -z $repo_ver ]] && repo_ver=0

        # update local pkgver
        cd $1/$p
        rm -rf src
        msg6 "updating git ..." # can take a while in some cases.
        git pull &>/dev/null || abort "Failed to update git repo for package [$p]. Aborting."
        sudo -iu ${SUDO_USER} repo=${PWD} bash -c 'cd ${repo}; makepkg -do &>/dev/null'
        git_ver=$(get_ver pkgver)-$(get_ver pkgrel)

        # compare, build if changed and install to chroot
        if [ $repo_ver == 0 ]; then
            msg6 "Package doesn't exist in repo."
        else
            msg6 "repo version: $repo_ver"
        fi
        if [ $(vercmp $git_ver $repo_ver) == 1 ]; then
            if [ $(vercmp ${repo_ver%-*} ${git_ver%-*}) == 1 ]; then
                reset_rel
            fi

            msg3 "building updated pkgver $git_ver"

            LOG_FILE="${LOG_DIR}/$p-$(date +'%Y%m%d%H%M')"
            msg4 "logfile: $LOG_FILE"
            echo "$(date -u) $p $git_ver" >> $log

            rm -rf src PKGBUILD &>/dev/null
            git checkout PKGBUILD &>/dev/null && git pull &>/dev/null
            chown ${SUDO_USER}:${SUDO_USER} PKGBUILD
            cd ..
            echo ${LOG_FILE} > $mon
            build_pkg $p &>${LOG_FILE}
            if [ $status != 0 ]; then
                build_err+=("${LOG_FILE}")
                err_build
            else
                cd ${START_DIR}/$1/$p
                git add PKGBUILD && git commit -m "$git_ver" &>/dev/null && git push &>/dev/null
            fi
            msg_wait
        else
            msg3 "unchanged."
        fi
        ((i=i+1))
        cd ${START_DIR}
    done

    rm $list $mon_wait $mon
    printf "+++ $(date -u) - PACKAGE UPDATE FINISHED. +++\n\n" >> $log
}

summary() {
    if [ ! -z ${build_err} ]; then
        err_build
        for e in "${build_err[@]}"; do
            echo "      $e"
        done
        echo ""
    fi
    msg4 "Finished."
}
