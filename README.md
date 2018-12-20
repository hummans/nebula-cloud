# nebula-cloud

Nebula Cloud host installer

 - Create and edit settings.sh
 - Run hostinstall.sh
 - Create Nebula setup template for each site
 - Run reconfigure


## settings.sh

```bash
site_url="example.com"
mail_host="smtp.example.com"
mail_user="smtpuser"
mail_pass="smtppassword"
support_email="support@example.com"
```

## sites directory

Create subdirectory for each site (name of this subdirectory will be used as "site_name") 
and put template dir (see nebula-setup) here:

```
sites/tv1/template
sites/tv2/template
sites/radio1/template
```
