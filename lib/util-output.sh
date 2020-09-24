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

enable_colors() {
    # prefer terminal safe colors and bold text when tput is supported
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
    readonly ALL_OFF BOLD BLUE GREEN RED YELLOW
}

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

error() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
} 
