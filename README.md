# Plone in a Box™

Your own [Plone 6](https://plone.org) website on a cloud server, without needing a command line.

Plone in a Box is for people who want a Plone site of their own but aren't system administrators. You fill in a
form on your cloud provider's website (Linode, DigitalOcean or Amazon AWS), choose an admin password, and click
Create. About 10 minutes later, the server's address shows your new Plone site, ready to log in and edit. There's
nothing to install on your computer.

Behind the scenes, each box is a single Ubuntu 24.04 server running the official Plone Docker images (the Plone
backend, the Volto front end and PostgreSQL) behind nginx, with:

* the admin password you choose when creating the server, or a randomly generated one (never `admin:admin`)
* a page that shows setup progress while you wait, and turns into your site when it's ready
* only the website (HTTP and HTTPS) and SSH reachable from the internet
* optional HTTPS from Let's Encrypt when you give it a domain name
* all Ubuntu updates installed during setup, and swap added on small servers

Default versions: Plone 6.2 with Volto 19. Both are configurable; for the previous release line, use Plone `6.1`
with Volto `18`.

## Get started

Pick a cloud provider. You'll need an account with them and a way to pay; a small site costs a few dollars a month on
Linode and DigitalOcean, and more on AWS.
A 1 GB server is enough for a small site on Linode and DigitalOcean (choose 2 GB or more for a busier one); on AWS,
use at least `t3.small` (2 GB).

The [setup guide](docs/setup-guide.md) has step-by-step instructions for each provider.

### Linode (Akamai)

1. In [Cloud Manager](https://cloud.linode.com), open **StackScripts → Community StackScripts**, search for
   **Plone in a Box**, and click **Deploy New Linode**.
2. Fill in the form. Set the **Plone admin password** (at least 12 characters); the domain name, time zone and
   versions are optional.
3. Choose **Ubuntu 24.04 LTS**, a region and a plan (a 1 GB Nanode is enough for a small site), set a root password,
   and pick **No firewall** if Cloud Manager asks for one (the server has its own).
4. Click **Create Linode**, then open the Linode's IP address in your browser.

Details: [setup guide, Linode](docs/setup-guide.md#option-a-linode).

### DigitalOcean

1. Open the launcher script, [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh),
   and copy all of it.
2. In the DigitalOcean control panel, **Create → Droplets**: choose **Ubuntu 24.04 (LTS) x64** and a size (1 GB is
   enough for a small site).
3. Under **Additional Options**, choose **Startup scripts (free)** and paste the launcher into the box.
   **Set the admin password between the quotes on its first setting line.**
4. Create the Droplet, then open its IP address in your browser.

Details: [setup guide, DigitalOcean](docs/setup-guide.md#without-terraform).

### Amazon AWS

1. Open the launcher script, [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh),
   and copy all of it.
2. In the AWS console, **EC2 → Launch instance**: choose **Ubuntu Server 24.04 LTS** and `t3.small`, allow HTTP and
   HTTPS traffic in **Network settings**, and change the disk to 20 GiB.
3. Under **Advanced details → User data**, paste the launcher. **Set the admin password between the quotes on its
   first setting line.**
4. Launch the instance, then open its public IPv4 address (with `http://`) in your browser.

Details: [setup guide, AWS console](docs/setup-guide.md#without-terraform-aws-console).

## Once your site is running

* **Log in** as `admin` with the password you chose. For everyday editing, create personal accounts in
  **Site Setup → Users and Groups**.
* **Forgot the password, or didn't set one?** Your provider has a console that runs in the browser: Linode's
  **Launch LISH Console**, DigitalOcean's **Access → Launch Droplet Console**, or AWS's **Connect → EC2 Instance
  Connect**. Open it and type one command: `sudo cat /root/plone-credentials.txt` shows a generated password, and
  `sudo plone-reset-admin-password` sets a new one.
* **Using your own domain name:** point the domain at the server's address before creating it, and fill in the
  domain and email settings to get HTTPS automatically. Adding a domain to an existing server takes a few commands;
  see [Adding HTTPS later](docs/setup-guide.md#adding-https-later).
* **Removing the site:** delete the server in your provider's control panel. This deletes the site's content too.

The setup guide also covers [backups, upgrades and troubleshooting](docs/setup-guide.md).

## For developers and system administrators

AWS and DigitalOcean can also be set up with Terraform from [`src/aws/`](src/aws/main.tf) and
[`src/digitalocean/`](src/digitalocean/main.tf). Both run the same provisioning script as the console routes,
[`src/StackScript`](src/StackScript), which is also the Linode StackScript.

```
cd src/aws            # or src/digitalocean, with DIGITALOCEAN_TOKEN set
terraform init
terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub' -var 'admin_password=...'
```

See the variables at the top of each `main.tf` for region, size, domain and versions, and the
[setup guide](docs/setup-guide.md#option-b-amazon-aws) for account setup. Pass the same `-var` options to
`terraform destroy`, or put them in `terraform.tfvars`. If Terraform fails with
`lookup sts.<region>.amazonaws.com: no such host` on a Mac, turn off iCloud Private Relay and retry.

On the server (`ssh root@<server>`, or `ubuntu@<server>` and `sudo -i` on AWS):

* setup is logged to `/var/log/plone-in-a-box.log`, and a generated admin password is saved in
  `/root/plone-credentials.txt`
* the stack lives in `/opt/plone`; manage it with
  `docker compose --project-directory /opt/plone ps|logs|pull|up -d`
* to add a domain later, point its DNS at the server and run `certbot --nginx -d <domain>`

## Releases

Development and releases happen at [tkimnguyen/plone-in-a-box](https://github.com/tkimnguyen/plone-in-a-box),
which is mirrored to [collective/plone-in-a-box](https://github.com/collective/plone-in-a-box) after each release.
Release notes are on the [Releases page](https://github.com/tkimnguyen/plone-in-a-box/releases), and
[CHANGES.md](CHANGES.md) lists the changes in every version. Both repositories have the same version tags.

Maintainers: see [RELEASING.md](RELEASING.md) for testing (including automated test deploys), releasing and syncing
to `collective/plone-in-a-box`.

## Background

The original step-by-step guide from the 2020 Plone Conference ([PDF](docs/archive/How_to_Setup_Your_Plone_in_a_Box™_(Ploneconf2020).pdf),
[markdown](docs/archive/How_to_Setup_Your_Plone_in_a_Box™_(Ploneconf2020).md)) describes the Plone 5.2 version; the account
setup steps still apply, but the port 8080 and `admin`/`admin` instructions no longer do.

See the accompanying [2020 Plone Conference](https://2020.ploneconf.org) presentation, Your Plone [Intranet] in a Box™:
* [presentation description](https://2020.ploneconf.org/talks/your-plone-intranet-in-a-boxtm/view)
* [slides](https://www2.slideshare.net/tkimnguyen/your-plone-intranet-in-a-box)
