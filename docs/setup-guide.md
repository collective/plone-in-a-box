# Setting up your Plone in a Box™

This guide takes you from a cloud account to a running Plone 6 site, on Linode, Amazon AWS or DigitalOcean. Allow about 20 minutes,
most of it waiting for the server to provision.

What you get: one Ubuntu 24.04 server running Plone 6.1 (backend), Volto 18 (the React front end) and PostgreSQL in
Docker, behind nginx. Only SSH (22), HTTP (80) and HTTPS (443) are open to the internet. You choose the Plone `admin`
password when deploying, or one is generated for you; there is no `admin`/`admin` login.

## Before you start

* **An SSH key.** On a Mac or Linux, check with `ls ~/.ssh/*.pub`. If nothing is listed, create one with
  `ssh-keygen -t ed25519`.
* **Server size.** Plone, Volto and PostgreSQL together need **at least 2 GB of RAM** (Linode 2 GB, AWS `t3.small`,
  DigitalOcean `s-1vcpu-2gb`).
  Smaller servers get swap added automatically but will be slow.
* **A domain name (optional).** For HTTPS, create a DNS `A` record pointing at the server's IP address *before*
  provisioning, or add HTTPS later (see [Adding HTTPS later](#adding-https-later)).

## Option A: Linode

1. Log in to [Cloud Manager](https://cloud.linode.com) and open **StackScripts → Community StackScripts**.
2. Search for **Plone in a Box**, open it, and click **Deploy New Linode**.
3. Fill in the **StackScript Options** (all optional):
   * **Plone admin password**: at least 12 characters. If you set it, you won't need SSH at all. If you leave it
     empty (or it's too short), a password is generated and saved on the server.
   * **Domain name** and **Email for Lets Encrypt**: both are needed for HTTPS.
   * **Site time zone**, for example `America/Chicago` (default `UTC`).
   * **Plone backend image tag** and **Volto frontend image tag** (defaults `6.1` and `18`).
4. Choose **Ubuntu 24.04 LTS** as the image, a region, and a **2 GB** (or larger) plan.
5. Set a root password, add your **SSH key**, and click **Create Linode**.

Cloud Manager asks you to choose a **Public Interface Firewall**. Pick **No firewall** if it's offered (the server runs
its own firewall, ufw, which allows only ports 22, 80 and 443). Otherwise create one named `plone-in-a-box` and reuse it
for every deploy: default inbound policy **Drop**, default outbound **Accept**, and three inbound **Accept** rules for
TCP ports **22**, **80** and **443** from all IPv4 and IPv6 addresses. A firewall without those rules blocks both SSH
and the site.

Wait about 10 minutes after the Linode shows *Running*, then open `http://<linode-ip>` (or your domain). If you set
an admin password, log in as `admin` and you're done; skip to step 2 of [After provisioning](#after-provisioning).
Otherwise continue with step 1 using `ssh root@<linode-ip>`. If the site doesn't load yet, give it a few more minutes:
the Linode's **Launch LISH Console** screen shows the site address once provisioning has finished.

## Option B: Amazon AWS (Terraform)

### One-time setup

1. Install Terraform and the AWS CLI. On a Mac:
   ```
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform awscli
   ```
2. Create an access key for Terraform. Don't use your AWS root account:
   * In the AWS console, open **IAM → Users → Create user**, name it (for example `terraform-plone`), and leave
     console access off.
   * **Attach policies directly**: choose **AmazonEC2FullAccess**, then create the user.
   * Open the user, go to **Security credentials → Create access key → Command Line Interface (CLI)**, and copy both
     keys. The secret is shown only once.
3. Run `aws configure`, paste the keys, and set the region (for example `us-east-1`). Check it with
   `aws sts get-caller-identity`.

### Deploy

```
git clone https://github.com/tkimnguyen/plone-in-a-box
cd plone-in-a-box/src/aws
terraform init
terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
```

Use the path of your own public key (for example `~/.ssh/id_rsa.pub`). To avoid repeating options, put them in
`src/aws/terraform.tfvars`:

```
ssh_public_key_path = "~/.ssh/id_rsa.pub"
# admin_password    = "a long password"  # optional; generated if empty
# domain            = "plone.example.org"
# letsencrypt_email = "you@example.org"
# site_timezone     = "America/Chicago"
```

Other variables (region, instance type, SSH source addresses, versions, disk size) are described at the top of
`src/aws/main.tf`. The account needs a default VPC, which new AWS accounts have.

Type `yes` to confirm. Terraform prints `site_url`, `public_ip` and `credentials_command`. The server then provisions
itself; follow along with:

```
ssh ubuntu@<public-ip> sudo tail -f /var/log/cloud-init-output.log
```

It's done when you see `[plone-in-a-box] Finished.` Continue with [After provisioning](#after-provisioning) using
`ssh ubuntu@<public-ip>` and `sudo`.

## Option C: DigitalOcean

### With Terraform

1. Install Terraform (see Option B) and create an API token: in the DigitalOcean control panel, go to **API →
   Tokens → Generate New Token**, give it **Full Access** (custom scopes need, at least, create/read/delete for droplets, SSH keys, firewalls and tags),
   and copy it. It's shown only once.
2. Deploy:
   ```
   export DIGITALOCEAN_TOKEN=<your token>
   git clone https://github.com/tkimnguyen/plone-in-a-box
   cd plone-in-a-box/src/digitalocean
   terraform init
   terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
   ```
   If that SSH key is already in your DigitalOcean account (**Settings → Security**), DigitalOcean won't accept it a
   second time. Pass its fingerprint instead: `-var 'ssh_key_fingerprint=aa:bb:cc:...'`.

   Options go in `src/digitalocean/terraform.tfvars` the same way as for AWS. Variables include `region` (default
   `nyc3`), `size` (default `s-1vcpu-2gb`), `backups`, `domain`, `letsencrypt_email`, `site_timezone` and the versions.
3. Terraform prints `site_url`, `public_ip` and `credentials_command`. The Droplet also gets a DigitalOcean Cloud
   Firewall that allows only ports 22, 80 and 443.

Follow provisioning with `ssh root@<public-ip> tail -f /var/log/cloud-init-output.log`, then continue with
[After provisioning](#after-provisioning).

### Without Terraform

1. **Create → Droplets**, choose **Ubuntu 24.04 (LTS) x64**, a 2 GB size, and your SSH key.
2. Under **Advanced Options**, check **Add initialization scripts** and paste the contents of
   [`src/StackScript`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/StackScript). To set
   options, add lines like these right after the first line (`#!/bin/bash`):
   ```
   export DOMAIN="plone.example.org"
   export LETSENCRYPT_EMAIL="you@example.org"
   export SITE_TIMEZONE="America/Chicago"
   ```
3. Create the Droplet. If you add a Cloud Firewall, allow inbound TCP 22, 80 and 443.

## After provisioning

1. If you didn't choose an admin password when deploying, read the generated one:
   ```
   sudo cat /root/plone-credentials.txt
   ```
   If the file doesn't exist yet, provisioning is still running. (If you did choose one, the file just confirms the
   site address.)
2. Open the site URL and log in as `admin`. Store the password in a password manager, then delete the file:
   `sudo rm /root/plone-credentials.txt`. For day-to-day editing, create personal accounts under
   **Site Setup → Users and Groups** and keep `admin` for administration.

   `admin` is a Zope-level user, so its password isn't changed in Site Setup. To change it later:
   ```
   sudo docker compose --project-directory /opt/plone run --rm -e NEW_ADMIN_PASSWORD='new-password-here' \
     -v /opt/plone/set_admin_password.py:/app/scripts/set_admin_password.py:ro \
     backend run /app/scripts/set_admin_password.py
   ```
3. Optional check: from your own computer, these should all time out:
   ```
   nc -zv -w 5 <server-ip> 5432
   nc -zv -w 5 <server-ip> 8080
   nc -zv -w 5 <server-ip> 3000
   ```

## Day-to-day administration

The stack lives in `/opt/plone` (`docker-compose.yml`, plus `.env` with the versions and database password), which
only root can read. Use `sudo -i` first, or prefix each command with `sudo`:

```
docker compose --project-directory /opt/plone ps                # status
docker compose --project-directory /opt/plone logs -f backend   # logs (backend, frontend or db)
docker compose --project-directory /opt/plone pull              # fetch newer images of the same tags
docker compose --project-directory /opt/plone up -d             # apply them
```

To move to a newer Plone or Volto release, change `PLONE_VERSION` / `VOLTO_VERSION` in `/opt/plone/.env`, then
run `pull` and `up -d`. Read the Plone upgrade notes first, and take a backup. Don't change `POSTGRES_VERSION` on an
existing server: a new PostgreSQL major version can't read the old data directory without a migration.

**Backups**: turn on your provider's server backups (Linode Backups, or EBS snapshots on AWS), and/or dump the
database regularly:

```
sudo docker compose --project-directory /opt/plone exec -T db pg_dump -U plone plone | gzip > plone-$(date +%F).sql.gz
```

## Adding HTTPS later

Point your domain's DNS at the server, wait until `dig +short <domain>` shows the server's IP, then:

```
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx --redirect -d <domain> -m <your-email> --agree-tos
```

## Removing the box

* **Linode**: delete the Linode in Cloud Manager.
* **AWS** or **DigitalOcean** with Terraform: `terraform destroy` from `src/aws/` or `src/digitalocean/`, with the
  same `-var` options (or `terraform.tfvars`) and, for DigitalOcean, the same `DIGITALOCEAN_TOKEN`.
* **DigitalOcean** without Terraform: destroy the Droplet in the control panel.
  Delete the AWS access key or DigitalOcean API token if you no longer need it.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `ssh: connect ... Operation timed out` on Linode | A Cloud Firewall is blocking port 22. Allow TCP 22, 80, 443, or detach it. |
| No `/root/plone-credentials.txt` after 15 minutes | Check `sudo docker compose --project-directory /opt/plone ps`, then `/var/log/cloud-init-output.log` on AWS, or log in via Linode's **LISH console**. |
| Terraform: `Value for undeclared variable` | You're running an old configuration. `git pull`, then `terraform init -upgrade` in `src/aws/`. |
| DigitalOcean: `SSH Key is already in use on your account` | Pass `-var 'ssh_key_fingerprint=...'` with the existing key's fingerprint. |
| DigitalOcean: `Unable to authenticate you` | `DIGITALOCEAN_TOKEN` isn't set in this terminal, or the token lacks write scope. |
| DigitalOcean: `You are missing the required permission tag:create` (or another `...:create`) | The token has custom scopes. Create one with **Full Access**, export it, and run `terraform apply` again. |
| Terraform: `no file exists at .../id_ed25519.pub` | Pass your key's path with `-var 'ssh_public_key_path=...'`, for `destroy` too. |
| Terraform on a Mac: `lookup sts.<region>.amazonaws.com: no such host` | Turn off iCloud Private Relay and retry. |
| Linode: "A UDF is missing the required 'name' attribute" | The script was modified with a `<UDF>` tag that has no `name`. Use the current `src/StackScript`. |

The [2020 Plone Conference guide](archive/) describes the original Plone 5.2 version and is kept for reference.
