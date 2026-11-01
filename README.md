# Plone in a Box™
An easy way to deploy a cloud server running Plone 6 with the Volto React front end.

Each box is a single Ubuntu 24.04 server running the official Plone Docker images
(backend, Volto frontend and PostgreSQL) behind nginx, with:

* a randomly generated admin password (no `admin:admin`)
* only SSH, HTTP and HTTPS reachable from the internet; Plone, Volto and PostgreSQL listen on localhost only
* optional HTTPS from Let's Encrypt when you give it a domain name
* swap added automatically on small servers

Default versions: Plone 6.1 with Volto 18. Both are configurable. Plone 6.2 is meant to be used with
Volto 19; switch to `6.2` / `19` once Volto 19 has a final release.

## Supported cloud providers

* **Linode**: [`src/StackScript`](src/StackScript), published as a Community StackScript
* **Amazon AWS**: [`src/aws.tf`](src/aws.tf) (Terraform), which runs the same script as EC2 user data
* **DigitalOcean**: not yet implemented; the StackScript should work unchanged as a Droplet user-data script

Use a server with at least 2 GB of RAM (Linode 2 GB, AWS `t3.small`).

### Linode

Deploy a new Linode from the StackScript, choosing Ubuntu 24.04 and adding your SSH key. Optional fields let you
set a domain name (for HTTPS), the site time zone, and the Plone/Volto versions. Provisioning takes about 10 minutes;
it is finished when `/root/plone-credentials.txt` exists.

### AWS

```
cd src
terraform init
terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
```

See the variables at the top of `aws.tf` for region, instance type, domain and versions. Progress is logged to
`/var/log/cloud-init-output.log`.

### After provisioning

```
ssh root@<server>          # or ubuntu@<server> on AWS, then sudo -i
cat /root/plone-credentials.txt
```

Open the site URL, log in as `admin` with that password, change the password, store it in a password manager and
delete the credentials file. The stack lives in `/opt/plone`; manage it with
`docker compose --project-directory /opt/plone ps|logs|pull|up -d`.

If you add a domain later, point its DNS at the server and run `certbot --nginx -d <domain>`.

## Background

The original step-by-step guide from the 2020 Plone Conference ([PDF](docs/How_to_Setup_Your_Plone_in_a_Box™_(Ploneconf2020).pdf),
[markdown](docs/How_to_Setup_Your_Plone_in_a_Box™_(Ploneconf2020).md)) describes the Plone 5.2 version; the account
setup steps still apply, but the port 8080 and `admin`/`admin` instructions no longer do.

See the accompanying [2020 Plone Conference](https://2020.ploneconf.org) presentation, Your Plone [Intranet] in a Box™:
* [presentation description](https://2020.ploneconf.org/talks/your-plone-intranet-in-a-boxtm/view)
* [slides](https://www2.slideshare.net/tkimnguyen/your-plone-intranet-in-a-box)
