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
    [[ ! -e $log ]] && echo "+++ package build log +++" > $log
}

get_ver() {
    ver=$(grep "^$1=" PKGBUILD | cut -d'=' -f2)
    echo $ver
}

reset_rel() {
    _rel=${git_ver#*-}
    if [[ $_rel != 1 ]]; then
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

summary() {
    if [[ ! -z ${build_err} ]]; then
        err_build
        for e in "${build_err[@]}"; do
            echo "      $e"
        done
        echo ""
    fi
    msg4 "Finished."
}

build_list() {
    cd ${START_DIR}
    prepare_list $1

    msg5 "* ${1%-git}: Building packages."
    i=1
    for p in $(cat $list); do
        header "${1%-git}: $i/$num - $p"
        LOG_FILE="${LOG_DIR}/$p-$(date +'%Y%m%d%H%M')"
        msg4 "logfile: $LOG_FILE"
        echo ${LOG_FILE} > $mon
        cd $1
        build_pkg $p &>${LOG_FILE}
        if [[ $status != 0 ]]; then
            printf "! FAILED [$p], see ${LOG_FILE}\n" >> $log
            build_err+=("${LOG_FILE}")
            err_build
        else
            printf "* BUILT  [$p] $git_ver\n" >> $log
        fi
        ((i=i+1))
        cd ${START_DIR}
    done

    printf ". DONE   [$1] $(date -u +"%y/%m/%d %R:%S %Z").\n\n" >> $log
}

build_list_git() {
    cd ${START_DIR}
    prepare_list $1

    msg5 "* ${1%-git}: Comparing git versions."
    i=1
    for p in $(cat $list); do
        header "${1%-git}: $i/$num - $p"
        repo_ver=$(sudo pacman -Siy "${p}" 2>/dev/null | grep "Version" | head -1 | cut -d":" -f2 | cut -d ' ' -f2)
        [[ -z $repo_ver ]] && repo_ver=0

        # update local pkgver
        cd $1/$p
        rm -rf src
        msg6 "updating git ..." # can take a while in some cases.
        [[ -d .git ]] && git pull &>/dev/null
        sudo -iu ${SUDO_USER} repo=${PWD} bash -c 'cd ${repo}; makepkg -do &>/dev/null'
        git_ver=$(get_ver pkgver)-$(get_ver pkgrel)

        # compare, build if changed and install to chroot
        if [[ $repo_ver == 0 ]]; then
            msg6 "Package doesn't exist in repo."
            repo_ver=r0
        else
            msg6 "repo version: $repo_ver"
        fi
        if [[ $(vercmp "$git_ver" "$repo_ver") == 1 ]]; then
            if [[ $(vercmp "${repo_ver%-*}" "${git_ver%-*}") == 1 ]]; then
                reset_rel
            fi
            if [[ ${PUSH_GIT} = true ]]; then
                git add PKGBUILD
                git commit -m "$git_ver" &>/dev/null
                git push &>/dev/null
            fi
            msg3 "building updated pkgver $git_ver"

            LOG_FILE="${LOG_DIR}/$p-$(date +'%Y%m%d%H%M')"
            msg4 "logfile: $LOG_FILE"
            rm -rf src PKGBUILD &>/dev/null
            git checkout PKGBUILD &>/dev/null && git pull &>/dev/null
            user_own PKGBUILD .git
            cd ..
            echo ${LOG_FILE} > $mon
            build_pkg $p &>${LOG_FILE}
            if [[ $status != 0 ]]; then
                printf "! FAILED [$p], see ${LOG_FILE}\n" >> $log
                build_err+=("${LOG_FILE}")
                err_build
            else
                printf "* BUILT  [$p] $git_ver\n" >> $log
            fi
            msg_wait
        else
            msg3 "unchanged."
        fi
        ((i=i+1))
        cd ${START_DIR}
    done

    printf ". DONE   [$1] $(date -u +"%y/%m/%d %R:%S %Z").\n\n" >> $log
}
