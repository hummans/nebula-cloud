#!/bin/bash

base_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
sites=($(ls -1 $base_dir/sites/))
tstamp=$(date +"%Y-%m-%d-%H-%M-%S")

source $base_dir/settings.sh

function backup_site(){
    site_name=$1
    strip_name=$(echo ${site_name} | sed s/\-//g)

    storage_dir="/mnt/${site_name}_01"
    backup_dir="${site_name}/.nx"
    target_dir="${backup_dir}/dbbackup.dir"

    if mount | grep /mnt/${site_name}_01 > /dev/null; then
        echo "Performing $site_name backup"
    else
        echo "Target storage is not mounted. Aborting"
        return 0
    fi

    if [ ! -d ${target_dir} ]; then
        mkdir -p ${target_dir} || return 1
    fi

    if [ -f /tmp/dbdump ]; then
        rm /tmp/dbdump || return 1
    fi

    db_name="nebula_${strip_name}"
    db_user="${strip_name}"
    db_pass="nebula"

    export PGPASSWORD="${db_pass}";
    pg_dump $db_name -U $db_user -h localhost > /tmp/dbdump || return 1
    cp /tmp/dbdump $target_dir/${site_name}-${tstamp}.sql || return 1
    return 0
}

function send_error(){
    site_name=$1
    msg="Database backup of the site $site_name has failed"
    echo $msg
    echo $msg | mail -s "DB Backup error" $support_email
}

for i in ${!sites[@]}; do
    site_name=${sites[$i]}
    backup_site $site_name || send_error $site_name
done
