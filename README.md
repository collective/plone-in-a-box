# Plone in a Box™
An easy way to deploy a cloud server running Plone 6 with the Volto React front end.

Each box is a single Ubuntu 24.04 server running the official Plone Docker images
(backend, Volto frontend and PostgreSQL) behind nginx, with:

* an admin password you choose when deploying, or a randomly generated one (no `admin:admin`)
* only SSH, HTTP and HTTPS reachable from the internet; Plone, Volto and PostgreSQL listen on localhost only
* optional HTTPS from Let's Encrypt when you give it a domain name
* swap added automatically on small servers

Default versions: Plone 6.2 with Volto 19. Both are configurable; for the previous release line, use Plone
`6.1` with Volto `18`.

## Releases

Development and releases happen at [tkimnguyen/plone-in-a-box](https://github.com/tkimnguyen/plone-in-a-box),
which is mirrored to [collective/plone-in-a-box](https://github.com/collective/plone-in-a-box) after each release.
Release notes are on the [Releases page](https://github.com/tkimnguyen/plone-in-a-box/releases), and
[CHANGES.md](CHANGES.md) lists the changes in every version. Both repositories have the same version tags.

## Supported cloud providers

* **Linode**: [`src/StackScript`](src/StackScript), published as the Community StackScript **Plone in a Box**
* **Amazon AWS**: [`src/aws/`](src/aws/main.tf) (Terraform), or [`src/user-data.sh`](src/user-data.sh) pasted into the EC2 console's **User data** box; both run the same script
* **DigitalOcean**: [`src/digitalocean/`](src/digitalocean/main.tf) (Terraform), or [`src/user-data.sh`](src/user-data.sh) pasted into the Droplet's **Startup scripts** box; both run the same script

Use a server with at least 2 GB of RAM on Linode (2 GB) and AWS (`t3.small`). On DigitalOcean, a 1 GB Droplet
(`s-1vcpu-1gb`) is enough for a small site; choose 2 GB or more for a busier one.

**Step-by-step instructions: [docs/setup-guide.md](docs/setup-guide.md)**, including AWS account setup, backups,
upgrades and troubleshooting.

### Linode

In Cloud Manager, search Community StackScripts for **Plone in a Box** and deploy a new Linode from it, choosing Ubuntu 24.04 and adding your SSH key. Optional fields let you
set the admin password, a domain name (for HTTPS), the site time zone, and the Plone/Volto versions. If you set the
admin password, no command line is needed: open the server's address right away to watch a setup progress page,
which turns into your Plone site when it's ready (about 10 minutes). Log in as `admin`. To reset the admin password
later, run `sudo plone-reset-admin-password` on the server.

Cloud Manager requires choosing a firewall: pick **No firewall** if offered, or a Cloud Firewall that allows inbound TCP 22, 80 and 443; a firewall with no inbound rules blocks SSH and the
site. The server also runs its own firewall (ufw) that allows only those ports.

### AWS

```
cd src/aws
terraform init
terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
```

See the variables at the top of `src/aws/main.tf` for region, instance type, domain and versions. Open the printed
`site_url` to watch setup progress; it's also logged to `/var/log/plone-in-a-box.log`.

Pass the same `-var` options to `terraform destroy` when you remove the box, or put them in `src/aws/terraform.tfvars`
(for example `ssh_public_key_path = "~/.ssh/id_rsa.pub"`) so both commands pick them up.

If Terraform fails with `lookup sts.<region>.amazonaws.com: no such host` on a Mac, turn off iCloud Private Relay and retry.

Without Terraform or a command line: in the AWS console, **EC2 → Launch instance** with **Ubuntu Server 24.04 LTS**,
`t3.small`, a 20 GiB disk, and HTTP and HTTPS allowed in **Network settings**. Paste
[`src/user-data.sh`](src/user-data.sh) into **Advanced details → User data**, set the admin password on its first
setting line, and launch. Then open the instance's public address to watch the setup progress page. If you forget
the password, use **Connect → EC2 Instance Connect** and run `sudo cat /root/plone-credentials.txt` (or
`sudo plone-reset-admin-password`). Step-by-step: [setup guide](docs/setup-guide.md#without-terraform-aws-console).

### DigitalOcean

Create an API token (DigitalOcean **API → Generate New Token**, with **Full Access**), then:

```
export DIGITALOCEAN_TOKEN=<your token>
cd src/digitalocean
terraform init
terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
```

If your SSH key is already in your DigitalOcean account, pass `-var 'ssh_key_fingerprint=<fingerprint>'` instead.
The Droplet gets a DigitalOcean Cloud Firewall allowing only ports 22, 80 and 443.

Without Terraform or a command line: when creating an Ubuntu 24.04 Droplet in the control panel, paste
[`src/user-data.sh`](src/user-data.sh) into **Additional Options → Startup scripts
(free)**. Set the admin password on its first setting line, and optionally the domain, time zone and versions.
Then open the Droplet's address to watch the setup progress page. If you forget the password, open **Access →
Launch Droplet Console** and run `cat /root/plone-credentials.txt` (or `plone-reset-admin-password`).

### After provisioning

If you left the admin password empty, read the generated one:

```
ssh root@<server>          # or ubuntu@<server> on AWS, then sudo -i
cat /root/plone-credentials.txt
```

Open the site URL, log in as `admin`, store the password in a password manager and delete the credentials file.
With Terraform, pass `-var 'admin_password=...'` (or set it in `terraform.tfvars`) to choose it yourself. The stack lives in `/opt/plone`; manage it with
`docker compose --project-directory /opt/plone ps|logs|pull|up -d`.

If you add a domain later, point its DNS at the server and run `certbot --nginx -d <domain>`.

## Background

The original step-by-step guide from the 2020 Plone Conference ([PDF](docs/archive/How_to_Setup_Your_Plone_in_a_Box™_(Ploneconf2020).pdf),
[markdown](docs/archive/How_to_Setup_Your_Plone_in_a_Box™_(Ploneconf2020).md)) describes the Plone 5.2 version; the account
setup steps still apply, but the port 8080 and `admin`/`admin` instructions no longer do.

See the accompanying [2020 Plone Conference](https://2020.ploneconf.org) presentation, Your Plone [Intranet] in a Box™:
* [presentation description](https://2020.ploneconf.org/talks/your-plone-intranet-in-a-boxtm/view)
* [slides](https://www2.slideshare.net/tkimnguyen/your-plone-intranet-in-a-box)

Maintainers: see [RELEASING.md](RELEASING.md) for testing, releasing and syncing to `collective/plone-in-a-box`.
