# nebula-cloud

Nebula cloud is a platform allowing to host multiple Nebula instances (sites). Sites share one PostgreSQL, NGINX and Memcached servers, but Nebula instances are spawned as Vagrant/Virtual box virtual hosts. Host machine also monitors its health and provides e-mail gateway (postfix).

## Installation

 - Create and edit settings.sh
 - Run hostinstall.sh
 - Create Nebula setup template for each site
 - Run reconfigure

### settings.sh

```bash
site_url="example.com"
mail_host="smtp.example.com"
mail_user="smtpuser"
mail_pass="smtppassword"
support_email="support@example.com"
host_ip="192.168.1.1" # IP address of the host
```

### sites directory

Create subdirectory for each site (name of this subdirectory will be used as "site_name")
and put template dir (see nebula-setup) here:

```
sites/tv1/template
sites/tv2/template
sites/radio1/template
```
