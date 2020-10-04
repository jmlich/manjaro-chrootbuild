#!/bin/bash

START_DIR=${PWD}
PKG_DIR=${START_DIR}
CHROOT_DIR=/var/lib/chrootbuild
BUILD_DIR=${CHROOT_DIR}/build
[[ $EUID = 0 ]] && USER_HOME=/home/${SUDO_USER} || USER_HOME=$HOME
BUILDUSER_UID="${SUDO_UID:-$UID}"
BUILDUSER_GID="$(id -g "${BUILDUSER_UID}")"
RM_PKGS=false
CLEAN=false
BUILD_LIST=false
INSTALL=false
SIGN=false
MIRROR='https://repo.manjaro.org/repo'
MIRROR_CONF=etc/pacman-mirrors.conf
mirror_conf=${CHROOT_DIR}/${MIRROR_CONF}
install_pkgs=()
lists=()
pkgs=()

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
    if [ "$EUID" -ne 0 ]; then
        err "This application needs to be run as root."
        exit 1
    fi
}

abort() {
  err "$1"
  [[ -e ${CHROOT_DIR}/.mount ]] && unmount_chroot ${CHROOT_DIR}
  exit 1
}

check_sanity() {
    if [ $BUILD_LIST = true ]; then
        if [ ! -f $1.list ]; then
            abort "Could not find buildlist [$1.list]. Aborting."
        elif [ ! -d $1 ]; then
            abort "Could not find directory [$1]. Aborting."
        fi
    elif [ ! -f $1/PKGBUILD ]; then
        abort "Could not find PKGBUILD for [$1]. Aborting."
    fi
}

job() {
    local func=$1
    shift
    arr=("$@")
    for i in ${arr[@]}; do
        $func $i
    done
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

    if [ -f "${ssh_env}" ]; then
         . "${ssh_env}" > /dev/null
         ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
            start_agent ${ssh_env};
        }
    else
        start_agent ${ssh_env};
    fi
}

usage() {
    echo ''
    echo "Usage: ${0##*/} [options]"
    echo ''
    echo '     -b <branch> Branch to use:'
    echo '                 (unstable/testing/stable-staging/stable;'
    echo '                 arm-unstable/arm-testing/arm-stable)'
    echo '                 default: unstable / arm-unstable'
    echo '     -c          Start with clean chroot fs'
    echo '     -h          This help'
    echo '     -i <pkg>    Install package(s) to chroot fs'
    echo '                 (for multiple packages repeat -i flag)'
    echo '     -l <list>   List(s) to build'
    echo '                 (for multiple lists repeat -l flag)'
    echo '     -n          Install built pkg to chroot fs'
    echo '     -p <pkg>    Package(s) to build'
    echo '                 (for multiple packages repeat -p flag)'
    echo '     -r          Remove previously built packages in $PKGDEST'
    echo '     -s          Sign package(s)'
    echo ''
    exit $1
}