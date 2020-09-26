#!/bin/bash

START_DIR=$PWD
CHROOT_DIR=/var/lib/chrootbuild
BUILD_DIR=${CHROOT_DIR}/build
[[ $EUID = 0 ]] && USER_HOME=/home/${SUDO_USER} || USER_HOME=$HOME
BUILDUSER_UID="${SUDO_UID:-$UID}"
BUILDUSER_GID="$(id -g "${BUILDUSER_UID}")"
RM_PKGS=false
CLEAN_CHROOT=false
SIGNPKG=false
INSTALL=false
MIRROR='https://repo.manjaro.org/repo'
BRANCH='arm-unstable'

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

msg() {
    local mesg=$1; shift
    printf "${YELLOW}${BOLD}  >>  ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
    local mesg=$1; shift
    printf "      ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg3() {
    local mesg=$1; shift
    printf "${GREEN}      ${mesg}${ALL_OFF}\n\n" "$@" >&2
}

msg4() {
    local mesg=$1; shift
    printf "${BOLD}      ${mesg}${ALL_OFF}\n\n" "$@" >&2
}

msg5() {
    local mesg=$1; shift
    printf "\n${BOLD}      ${mesg}${ALL_OFF}\n\n" "$@" >&2
}

err() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        err "This application needs to be run as root."
        exit 1
    fi
}

usage() {
    echo ''
    echo "Usage: ${0##*/} [options] <package>"
    echo ''
    echo '     -b <branch> Branch to use (arm-unstable/arm-testing/arm-stable'
    echo '                                default: arm-unstable)'
    echo '     -c          Start with clean chroot fs'
    echo '     -h          This help'
#   echo '     -i <pkg>    Install pkg to chroot fs'
    echo '     -n          Install built pkg to chroot fs'
    echo '     -r          Remove previously built packages in $PKGDEST'
    echo '     -s          Sign package'
    echo ''
    exit $1
}
