#!/bin/bash

source settings.sh
source common.sh

# Set root's full name (kvuli mailum)
root_full_name="Nebula Cloud ($(hostname))"
chfn -f "$root_full_name" root


function install_base {
    apt update || return 1
    apt install -y \
        curl \
        vim \
        aptitude \
        dirmngr \
        apt-transport-https \
        python3 \
        python3-pip \
        cifs-utils \
        python3-dev \
        build-essential \
        linux-headers-$(uname -r) || return 1

    pip3 install pylibmc psutil psycopg2-binary pyyaml requests || return 1
}


function install_mail {
    apt remove --purge postfix

    debconf-set-selections <<< "postfix postfix/mailname string $site_url"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Satellite system'"
    debconf-set-selections <<< "postfix postfix/relayhost string $mail_host"
    apt -y install mailutils sasl2-bin postfix

    echo "$mail_host $mail_user:$mail_pass" > /etc/postfix/sasl_passwd
    chown root:root /etc/postfix/sasl_passwd; chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd

    echo "root $(hostname)@${site_url}" >> /etc/postfix/generic
    postmap /etc/postfix/generic

    echo "smtp_sasl_auth_enable = yes" >> /etc/postfix/main.cf
    echo "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" >> /etc/postfix/main.cf
    echo "smtp_sasl_security_options =" >> /etc/postfix/main.cf
    echo "smtp_generic_maps = hash:/etc/postfix/generic" >> /etc/postfix/main.cf

    systemctl restart postfix

    echo "Testing e-mail settings on $(hostname)" | mail -s "Test mail" $support_email
}


function install_mdadm {
    apt -y remove --purge mdadm
    debconf-set-selections <<< "mdadm mdadm/mail_to string $support_email"
    debconf-set-selections <<< "mdadm mdadm/autocheck string true"
    debconf-set-selections <<< "mdadm mdadm/start_daemon string true"
    apt -y install mdadm || return 1
}


function install_virtualbox {
    wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add - || return 1
    wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | apt-key add - || return 1
    echo "deb https://download.virtualbox.org/virtualbox/debian $debian_version contrib" > /etc/apt/sources.list.d/virtualbox.list
    apt update || return 1
    apt -y install virtualbox-5.2 || return 1
    /sbin/vboxconfig || return 1
}


function install_vagrant {
    vagrant_url="https://releases.hashicorp.com/vagrant/2.2.0/vagrant_2.2.0_x86_64.deb" || return 1
    vagrant_path="/tmp/vagrant.deb"
    if [ ! -f $vagrant_path ]; then
        rm $vagrant_path
    fi
    wget $vagrant_url -O $vagrant_path
    dpkg -i $vagrant_path || return 1
}


function install_ansible {
    echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" > /etc/apt/sources.list.d/ansible.list
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 || return 1
    apt update || return 1
    apt -y install ansible || return 1
}


function install_postgres {
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $debian_version-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - || return 1
    apt-get update
    apt -y install \
        postgresql-11 \
        postgresql-client-11 \
        postgresql-contrib-11 || return 1
}


function install_memcached {
    apt -y install memcached || return 1
    echo "-d" > /etc/memcached.conf
    echo "logfile /var/log/memcached.log" >> /etc/memcached.conf
    echo "-m 1024" >> /etc/memcached.conf
    echo "-p 11211" >> /etc/memcached.conf
    echo "-u memcache" >> /etc/memcached.conf
    systemctl restart memcached || return 1
}


function install_nginx {
    cd /opt
    if [ -d installers ]; then
        cd installers
        git pull || return 1
    else
        git clone https://github.com/immstudios/installers || return 1
        cd installers
    fi
    ./install.nginx.sh || return 1

    rm -rf /var/www/default
    ln -s $base_dir/var/www/default /var/www/default
}


function install_certbot {
    apt -y install certbot || return 1
    cd /opt
    if [ -d "domain-tool" ]; then
        cd domain-tool
        git pull || return 1
    else
        git clone https://github.com/immstudios/domain-tool || return 1
        cd domain-tool
    fi
    domains_list=$(IFS=, ; echo "${domains[*]}")
    echo "domains = ${domains_list}" > /opt/domain-tool/config/$site_url
    echo "rsa-key-size = 4096" >> /opt/domain-tool/config/$site_url
    echo "email = ${support_email}" >> /opt/domain-tool/config/$site_url
    echo "text = true" >> /opt/domain-tool/config/$site_url
    echo "authenticator = webroot" >> /opt/domain-tool/config/$site_url
    echo "webroot-path = /var/www/default/lets-encrypt" >> /opt/domain-tool/config/$site_url

    ./install.sh || return 1
}


function install_nebula_setup {
    cd /opt
    if [ -d nebula-setup ]; then
        cd nebula-setup
        git pull || return 1
    else
        git clone https://github.com/nebulabroadcast/nebula-setup || return 1
    fi
}


install_base || critical_error
install_mail || critical_error
install_virtualbox || critical_error
install_vagrant || critical_error
install_ansible || critical_error
install_postgres || critical_error
install_memcached || critical_error
install_nginx || critical_error
install_certbot || critical_error
install_nebula_setup || critical_error

cd $orig_dir
