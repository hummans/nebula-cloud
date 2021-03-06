#!/bin/bash

source settings.sh
source common.sh

machines_dir="/var/nebula-cloud"


sites=($(ls -1 sites/))
domains=("${sites[@]}")
for i in ${!domains[@]}
do
    domains[$i]="${domains[$i]}.$site_url"
done


function create_certs {
    domains_list=$(IFS=, ; echo "${domains[*]}")
    certconfig_path="/opt/domain-tool/config/$site_url"

    if [ -f $certconfig_path ]; then
        oldsum=$(md5sum $certconfig_path)
    else
        oldsum="nothing"
    fi

    echo "domains = ${domains_list}" > $certconfig_path
    echo "rsa-key-size = 4096" >> $certconfig_path
    echo "email = ${support_email}" >> $certconfig_path
    echo "text = true" >> $certconfig_path
    echo "authenticator = webroot" >> $certconfig_path
    echo "webroot-path = /var/www/default/lets-encrypt" >> $certconfig_path

    newsum=$(md5sum $certconfig_path)

    if [[ $oldsum != $newsum ]]; then
        echo "SSL Cert config has been changed. Renewing"
        cd /opt/domain-tool
        ./update-cert.sh
    fi

    cd $orig_dir
}


function create_db {
    if [ ! -d /opt/nebula-setup ]; then
        critical_error "nebula-setup is not installed. Run hostinstall.sh first"
    fi
    site_name=$1

    stripname=$(echo ${site_name} | sed s/\-//g)
    db_name="nebula_${stripname}"
    db_user="${stripname}"
    db_pass="nebula"

    echo "Checking user $db_user"
    su postgres -c \
        "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='${db_user}'\"" \
        | grep -q 1 || su postgres -c \
        "psql -tc \"CREATE ROLE ${db_user} LOGIN PASSWORD '${db_pass}';\"" || return 1

    echo "Checking database $db_name"
    su postgres -c \
        "psql -tc \"SELECT 1 FROM pg_database WHERE datname='${db_name}'\"" \
        | grep -q 1 || ( \
        su postgres -c "psql -tc \"CREATE DATABASE ${db_name} OWNER ${db_user};"\" \
        && export PGPASSWORD="${db_pass}"; psql -h localhost -U ${db_user} ${db_name} \
        --file=/opt/nebula-setup/support/schema.sql
        ) || return 1
}

function setup_nebula {
    site_name=$1
    tpl_dir=$base_dir/sites/$site_name/template
    tgt_dir=/opt/nebula-setup/template

    stripname=$(echo ${site_name} | sed s/\-//g)
    db_name="nebula_${stripname}"
    db_user="${stripname}"
    db_pass="nebula"

    if [ -L $tgt_dir ]; then
        rm $tgt_dir
    fi
    ln -s $tpl_dir $tgt_dir
    cd /opt/nebula-setup

    echo "{" > settings.json
    echo "    \"site_name\" : \"$site_name\"," >> settings.json
    echo "    \"db_host\" : \"localhost\"," >> settings.json
    echo "    \"db_user\" : \"$db_user\"," >> settings.json
    echo "    \"db_pass\" : \"$db_pass\"," >> settings.json
    echo "    \"db_name\" : \"$db_name\"" >> settings.json
    echo "}" >> settings.json

    ./setup.py
    cd $orig_dir
}


function create_machines {
    site_name=$1
    source_machines_dir=$base_dir/sites/$site_name/machines

    stripname=$(echo ${site_name} | sed s/\-//g)
    db_name="nebula_${stripname}"
    db_user="${stripname}"
    db_pass="nebula"
    db_host=${host_ip}

    rm ${machines_dir}/${site_name}/hosts
    for machine_config in $source_machines_dir/*; do
        if [ -f $machine_config ]; then

            source $machine_config

            machine_name=$(basename $machine_config)
            machine_dir=$machines_dir/$site_name/$machine_name

            echo "Performing setup for $machine_name "

            if [ ! -d $machine_dir ]; then
                mkdir -p $machine_dir
            fi

            if [ ! -e $machine_dir/roles ]; then
                ln -s $base_dir/roles $machine_dir/
            fi

            cp $base_dir/support/Vagrantfile $machine_dir/

            settings=$machine_dir/settings.rb
            echo "module VagrantSettings" > $settings
            echo "    HOSTNAME = \"$machine_name\"" >> $settings
            echo "    IP       = \"$ip\"" >> $settings
            echo "    CPUS     = \"$cpus\"" >> $settings
            echo "    MEMORY   = \"$memory\"" >> $settings
            echo "end" >> $settings

            playbook=$machine_dir/playbook.yml

            echo "---" > $playbook

            echo "- name: provision" >> $playbook
            echo "  hosts: all" >> $playbook
            echo "  become: true" >> $playbook
            echo "  become_user: root" >> $playbook
            echo "  become_method: sudo" >> $playbook
            echo "  gather_facts: false" >> $playbook
            echo "  tasks:" >> $playbook
            echo "  - include_role: name=common" >> $playbook

            for j in ${!roles[@]}
            do
               echo "  - include_role: name=${roles[$j]}" >> $playbook
               if [[ ${roles[$j]} == "hub" ]]; then
                   echo "Creating ${site_name}core DNS record for ${ip}"
                   echo "${ip}    ${site_name}core" >> ${machines_dir}/${site_name}/hosts
               fi
            done

            echo "  vars:" >> $playbook
            echo "      site_name: \"$site_name\"" >> $playbook
            echo "      db_host: \"$db_host\"" >> $playbook
            echo "      db_name: \"$db_name\"" >> $playbook
            echo "      db_user: \"$db_user\"" >> $playbook
            echo "      db_pass: \"$db_pass\"" >> $playbook

        fi
    done

    # Update DNS records

    hosts_path=${machines_dir}/hosts
    if [ -f $hosts_path ]; then
        oldsum=$(md5sum $hosts_path)
    else
        oldsum="nothing"
    fi

    rm $hosts_path
    for i in ${!sites[@]}; do
        site_name=${sites[$i]}
        cat ${machines_dir}/${site_name}/hosts >> $hosts_path
    done

    newsum=$(md5sum $hosts_path)

    if [[ $oldsum != $newsum ]]; then
        echo "Hosts files has been changed. Restarting dnsmasq"
        systemctl restart dnsmasq
    fi
    cd $orig_dir
}

#
# Run everything
#

if [ -z  $1 ]; then
    critical_error "You must provide site name as an argument"
fi
if [ ! -d sites/$1 ]; then
    critical_error "Site \"$1\" does not exist"
fi

create_certs || critical_error
create_db $1 || critical_error
setup_nebula $1 || critical_error
create_machines $1 || critical_error

finished
