#!/bin/bash

ARCH=$(uname -m)
START_DIR=${PWD}
CHROOT_DIR=/var/lib/chrootbuild
PAC_CONF_TPL=/etc/chrootbuild/pacman.conf.${ARCH}
[[ $EUID = 0 ]] && USER_HOME=/home/${SUDO_USER} || USER_HOME=$HOME
BUILDUSER_UID="${SUDO_UID:-$UID}"
BUILDUSER_GID="$(id -g "${BUILDUSER_UID}")"
RM_PKGS=false
CLEAN=false
INSTALL_LOCAL=false
PUSH_GIT=false
INSTALL=false
UPDATE=false
MODULES=false
SIGN=false
MULTILIB=false
COLORS=true
DEBUG=false
LTO=false
FORCE_UNMOUNT=false
CHECKSUMS=false
HOST_KEYS=false
MIRROR='https://repo.manjaro.org/repo'
MIRROR_CONF=etc/pacman-mirrors.conf
MP_CONF_GLOB='/etc/makepkg.conf'
MP_CONF_USER="${USER_HOME}/.makepkg.conf"
install_pkgs=()
lists=()
pkgs=()
custom_repo=
check=none
shopt -s dotglob

enable_colors() {
    if tput setaf 0 &>/dev/null; then
        ALL_OFF="$(tput sgr0)"
        BOLD="$(tput bold)"
        RED="${BOLD}$(tput setaf 1)"
        GREEN="${BOLD}$(tput setaf 2)"
        YELLOW="${BOLD}$(tput setaf 3)"
        BLUE="${BOLD}$(tput setaf 4)"
    else
        ALL_OFF="\e[0m"
        BOLD="\e[1m"
        RED="${BOLD}\e[31m"
        GREEN="${BOLD}\e[32m"
        YELLOW="${BOLD}\e[33m"
        BLUE="${BOLD}\e[34m"
    fi
}

header() {
    local mesg=$1; shift
    printf "${YELLOW}${BOLD}  >>  ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
    local mesg=$1; shift
    printf "\n${GREEN}${BOLD}:: ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
    local mesg=$1; shift
    printf "      ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg3() {
    local mesg=$1; shift
    printf "\n${GREEN}      ${mesg}${ALL_OFF}\n\n" "$@" >&2
}

msg4() {
    local mesg=$1; shift
    printf "${BOLD}      ${mesg}${ALL_OFF}\n\n" "$@" >&2
}

msg5() {
    local mesg=$1; shift
    printf "\n${BOLD}      ${mesg}${ALL_OFF}\n\n" "$@" >&2
}

msg6() {
    local mesg=$1; shift
    printf "\r      ${mesg}${ALL_OFF}" "$@" >&2
}

err() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

err_choice() {
    local mesg=$1; shift
    printf "\n${RED}:: ERROR:${ALL_OFF}${BOLD} ${mesg} ${ALL_OFF}" "$@" >&2
}

err_build() {
    printf "${RED}${BOLD}      Errors have occurred.${ALL_OFF} Check the log!\n\n"
}

check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        err "This application needs to be run as root."
        exit 1
    fi
}

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

cleanup() {
    mesg=${1:-"Cleaning up."}
    msg4 "$mesg"
    umount -l ${CHROOT_DIR} 2>/dev/null
    for f in ${CHROOT_DIR}/.{mount,lock} "${START_DIR}/*.list.work" $mon $mon_wait; do
        [[ -e $f ]] && rm $f
    done
    return 0
    }

abort() {
    err "$1"
    cleanup
    exit 1
}

job() {
    local func=$1
    shift
    arr=("$@")
    for i in ${arr[@]}; do
        $func $i
    done
}

check_sanity() {
    if [[ ${check} = list ]]; then
        if [[ ! -f $1.list ]]; then
            abort "Could not find buildlist [$1.list]. Aborting."
        elif [[ ! -d $1 ]]; then
            abort "Could not find directory [$1]. Aborting."
        fi
    elif [[ ! -f $1/PKGBUILD ]]; then
        abort "Could not find PKGBUILD for [$1]. Aborting."
    fi
}

prepare_lists() {
    check=list
    job check_sanity "${lists[@]}"
    . ${LIBDIR}/util-lists.sh
    msg_wait
    prepare_log
    #ssh_add
    msg "List(s) to build:"
    printf " - %s\n" "${lists[@]//\//}"
    printf "\n$(date -u +"%y/%m/%d %R:%S %Z"):\nBUILDING LISTS\n" >> $log
    printf " - %s\n" "${lists[@]//\//}" >> $log
    echo "" >> $log
}

prepare_pkgs() {
    check=package
    job check_sanity "${pkgs[@]}"
    msg "Package(s) to build:"
    printf "   - %s\n" "${pkgs[@]//\//}"
}

root_own() {
    chown -R root:root .
}

user_own() {
    chown -R ${BUILDUSER_UID}:${BUILDUSER_GID} .
}

start_agent(){
    echo "Initializing SSH agent..."
    ssh-agent | sed 's/^echo/#echo/' > "$1"
    chmod 600 "$1"
    . "$1" > /dev/null
    ssh-add
}

ssh_add(){
    local ssh_env="$USER_HOME/.ssh/environment"

    if [[ -f "${ssh_env}" ]]; then
         . "${ssh_env}" > /dev/null
         ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
            start_agent ${ssh_env};
        }
    else
        start_agent ${ssh_env};
    fi
}

usage_chrootbuild() {
    echo ''
    echo "Usage: ${0##*/} [options]"
    echo ''
    echo '     -b <branch> Branch to use:'
    echo '                 (unstable/testing/stable-staging/stable;'
    echo '                 arm-unstable/arm-testing/arm-stable)'
    echo '                 default: unstable / arm-unstable'
    echo '     -c          Start with clean chroot fs'
    echo '     -d          Disable colors.'
    echo '     -D          Build with debug symbols.'
    echo '     -f          Force unmount chroot if busy.'
    echo '     -g          Push changes to git when building lists'
    echo '     -G          Generate Checksums'
    echo '     -h          This help'
    echo "     -H          Use the host's keyrings"
    echo '     -i <pkg>    Install package(s) to chroot fs'
    echo '                 (for multiple packages repeat -i flag)'
    echo '     -k <repo>   Use custom repo:'
    echo '                 (mobile/kde-unstable)'
    echo '     -K <list>   Kernel-modules list to build'
    echo '     -l <list>   List(s) to build'
    echo '                 (for multiple lists repeat -l flag)'
    echo '     -L          enable LinkTimeOptimization'
    echo '     -m          Build a multilib package'
    echo '     -M <url>    Use custom mirror'
    echo '     -n          Install built pkg to chroot fs'
    echo '     -p <pkg>    Package(s) to build'
    echo '                 (for multiple packages repeat -p flag)'
    echo '     -r          custom chrootdir path'
    echo '                 default: /var/lib/chrootbuild'
    echo '     -s          Sign package(s)'
    echo '     -u          Build pkgs only if update available (lists only)'
    echo '     -x          Remove previously built packages in $PKGDEST'
    echo ''
    exit $1
}

usage_prepare_chroot() {
    echo ''
    echo "Usage: ${0##*/} [options]"
    echo ''
    echo '     -b <branch> Branch to use:'
    echo '                 (unstable/testing/stable-staging/stable;'
    echo '                 arm-unstable/arm-testing/arm-stable)'
    echo '                 default: unstable / arm-unstable'
    echo '     -c          Create clean chroot filesystem'
    echo '     -f          Force unmount chroot if busy.'
    echo '     -h          This help'
    echo "     -H          Use the host's keyrings"
    echo '     -k <repo>   Use custom repo:'
    echo '                 (mobile/kde-unstable)'
    echo '     -m          Keep Chroot filesystem mounted'
    echo '     -M <url>    Use custom mirror'
    echo '     -u          Unmount Chroot filesystem cleanly'
    echo ''
    exit $1
}
