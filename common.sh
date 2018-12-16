#!/bin/bash

orig_dir=$(pwd)
base_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
temp_dir=/tmp/$(basename "${BASH_SOURCE[0]}")
debian_version="$(lsb_release --codename | cut -f2)"

function critical_error {
    printf "\n\033[0;31mInstallation failed\033[0m\n"
    cd $orig_dir
    exit 1
}

function finished {
    printf "\n\033[0;92mInstallation completed\033[0m\n"
    cd $orig_dir
    exit 0
}

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   critical_error
fi

if [ ! -d $TEMP_DIR ]; then
    mkdir $TEMP_DIR || critical_error
fi

