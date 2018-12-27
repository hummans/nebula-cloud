#!/bin/bash

source settings.sh
source common.sh

sites=($(ls -1 sites/))
domains=("${sites[@]}")
for i in ${!domains[@]}
do
    domains[$i]="${domains[$i]}.$site_url"
done


function create_certs {
    domains_list=$(IFS=, ; echo "${domains[*]}")

    echo "domains = ${domains_list}" > /opt/domain-tool/config/$site_url
    echo "rsa-key-size = 4096" >> /opt/domain-tool/config/$site_url
    echo "email = ${support_email}" >> /opt/domain-tool/config/$site_url
    echo "text = true" >> /opt/domain-tool/config/$site_url
    echo "authenticator = webroot" >> /opt/domain-tool/config/$site_url
    echo "webroot-path = /var/www/default/lets-encrypt" >> /opt/domain-tool/config/$site_url

    cd /opt/domain-tool
    ./update-cert.sh
    cd $orig_dir
}


function create_db {
    if [ ! -d /opt/nebula-setup ]; then
        echo "nebula-setup is not installed. Run hostinstall.sh first"
        critical_error
    fi

    for i in ${!sites[@]}
    do
        site_name=${sites[$i]}
        db_name="nebula_${site_name}"
        db_user="${site_name}"
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
    done
}

function setup_nebula {
    for i in ${!sites[@]}
    do
        site_name=${sites[$i]}
        tpl_dir=$base_dir/sites/$site_name/template
        tgt_dir=/opt/nebula-setup/template

        db_name="nebula_${site_name}"
        db_user="${site_name}"
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

    done

}


#
# Run everything
#

#create_db || critical_error
#create_certs || critical_error
setup_nebula


finished
