# Plone in a Box™

Your own [Plone 6](https://plone.org) website on a cloud server, without needing a command line.

Plone in a Box is for people who want a Plone site of their own but aren't system administrators. You fill in a
form on your cloud provider's website (Linode, DigitalOcean, Amazon AWS or Hetzner), choose an admin password, and click
Create. About 10 minutes later, the server's address shows your new Plone site, ready to log in and edit. There's
nothing to install on your computer.

Behind the scenes, each box is a single Ubuntu 26.04 LTS server running the official Plone Docker images (the Plone
backend, the Volto front end and PostgreSQL) behind nginx, with:

* the admin password you choose when creating the server, or a randomly generated one (never `admin:admin`)
* a page that shows setup progress while you wait, and turns into your site when it's ready
* only the website (HTTP and HTTPS) and SSH reachable from the internet
* optional HTTPS from Let's Encrypt when you give it a domain name
* all Ubuntu updates installed during setup, and swap added on small servers

Default versions: Plone 6.2 with Volto 19. Both are configurable; for the previous release line, use Plone `6.1`
with Volto `18`.

## Get started

Pick a cloud provider. You'll need an account with them and a way to pay.

**Which one?** If you don't already use one of these, choose **Linode**: it has the simplest setup (a form with
labelled fields, nothing to paste) and among the lowest prices for a small site. Choose **DigitalOcean** if you
already have an account there; it costs about the same. Choose **AWS** if your organization already runs things
there; its Launch Stack button opens a similar form, but a small site costs noticeably more. Choose **Hetzner**
if you prefer a European provider; it costs about the same, and setup works like DigitalOcean's. The setup guide
[compares them](docs/setup-guide.md#choosing-a-provider).

A 1 GB server is enough for a small site on Linode, DigitalOcean and Hetzner (choose 2 GB or more for a busier one);
on AWS, use at least `t3.small` (2 GB).

The [setup guide](docs/setup-guide.md) has step-by-step instructions for each provider.

### Linode (Akamai)

1. Log in to [Cloud Manager](https://cloud.linode.com), open the
   [Plone in a Box StackScript](https://cloud.linode.com/stackscripts/931893) (by **nguyen-plone**), and click
   **Deploy New Linode**.
2. Fill in the form. Set the **Plone admin password** (at least 12 characters); the domain name, time zone,
   versions, backend add-ons and a theme are optional.
3. Choose **Ubuntu 26.04 LTS** (24.04 also works), a region and a plan (a 1 GB Nanode is enough for a small
   site), set a root password, and pick **No firewall** if Cloud Manager asks for one (the server has its own).
4. Click **Create Linode**, then open the Linode's IP address in your browser.

Details: [setup guide, Linode](docs/setup-guide.md#option-a-linode).

### DigitalOcean

1. In the DigitalOcean control panel, **Create → Droplets**: choose **Ubuntu 26.04 (LTS) x64** and a size (1 GB is
   enough for a small site).
2. Under **Additional Options**, choose **Startup scripts (free)** and paste these three lines into the box. Replace
   `CHANGE-ME` with your admin password (at least 12 characters), keeping the quotes:
   ```
   #!/bin/bash
   export ADMIN_PASSWORD='CHANGE-ME'
   curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.14/src/StackScript && bash /root/plone-in-a-box.sh
   ```
3. Create the Droplet, then open its IP address in your browser.

For more settings (a domain for HTTPS, the time zone, versions, add-ons, a theme), paste [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh) instead.

Details: [setup guide, DigitalOcean](docs/setup-guide.md#console-deployment-easiest-1).

### Amazon AWS

1. Sign in to the [AWS console](https://console.aws.amazon.com/), then click
   [![Launch Stack](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https%3A%2F%2Fplone-in-a-box-templates.s3.us-east-1.amazonaws.com%2Flatest%2Fcloudformation.yaml&stackName=plone-in-a-box)
2. Fill in the form: set the **Plone admin password** (at least 12 characters); everything else is optional.
3. Click **Create stack**. When it shows `CREATE_COMPLETE` (a minute or two), open the **SiteURL** on its
   **Outputs** tab.

Details: [setup guide, AWS console](docs/setup-guide.md#console-deployment-easiest).

### Hetzner

1. In the [Hetzner Console](https://console.hetzner.com), open a project and click **Create server**: choose a
   **Regular Performance** plan (**CPX02**, 1 GB, is enough for a small site; CPX11 in the US), a location and
   **Ubuntu 26.04**.
2. Under **Cloud config**, paste these three lines into the "Cloud-init configuration" box. Replace `CHANGE-ME` with
   your admin password (at least 12 characters), keeping the quotes:
   ```
   #!/bin/bash
   export ADMIN_PASSWORD='CHANGE-ME'
   curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.14/src/StackScript && bash /root/plone-in-a-box.sh
   ```
3. Click **Create & Buy now**, then open the server's IPv4 address in your browser.

For more settings (a domain for HTTPS, the time zone, versions, add-ons, a theme), paste [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh) instead.

Details: [setup guide, Hetzner](docs/setup-guide.md#console-deployment-easiest-2).

## Once your site is running

* **Log in** as `admin` with the password you chose. For everyday editing, create personal accounts in
  **Site Setup → Users and Groups**.
* **Forgot the password, or didn't set one?** Your provider has a console that runs in the browser: Linode's
  **Launch LISH Console**, DigitalOcean's **Access → Launch Droplet Console**, AWS's **Connect → EC2 Instance
  Connect**, or Hetzner's **Console** (the `>_` button on the server's page). Open it and type one command: `sudo cat /root/plone-credentials.txt` shows a generated password, and
  `sudo plone-reset-admin-password` sets a new one.
* **Using your own domain name:** point the domain at the server's address before creating it, and fill in the
  domain and email settings to get HTTPS automatically. Adding a domain to an existing server takes a few commands;
  see [Adding HTTPS later](docs/setup-guide.md#adding-https-later).
* **Removing the site:** delete the server in your provider's control panel. This deletes the site's content too.

* **Add-ons:** backend add-ons such as `collective.easyform` can be installed when deploying, or later; see
  [Add-ons](docs/setup-guide.md#add-ons).
* **Volto Light Theme:** set the frontend image to `ghcr.io/collective/plone-in-a-box-frontend:19-vlt` when
  deploying; see [Themes and frontend images](docs/setup-guide.md#themes-and-frontend-images).
* **Demo login:** an extra login, with the roles and password you choose (or a generated password), for letting
  others try the site; see
  [Demo login](docs/setup-guide.md#demo-login). Add-on authors can use it for a
  [Try it button](#for-add-on-authors-a-try-it-button).
* **Updates:** Ubuntu installs its security updates by itself, and every week the server installs Plone, Volto and
  PostgreSQL patch releases, after a database backup, and undoes them if the site doesn't come back. Reports can go
  to your phone (ntfy), a team chat, or by email; see [Updates](docs/setup-guide.md#updates). A server set up
  before 2.12 gets them with [one command](docs/setup-guide.md#servers-set-up-before-212).

The setup guide also covers [backups, upgrades and troubleshooting](docs/setup-guide.md).

## For add-on authors: a "Try it" button

Let people try your Plone add-on in a real site of their own, in about 10 minutes, without installing anything:
buttons in your add-on's README set up Plone in a Box on their cloud account, with your add-on installed and a
demo login to share. [Juizi Dashboard](https://github.com/tkimnguyen/juizi.dashboard#try-it) does this:

[![Launch Stack on AWS](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https%3A%2F%2Fplone-in-a-box-templates.s3.us-east-1.amazonaws.com%2Flatest%2Fcloudformation.yaml&stackName=juizi-dashboard-demo&param_FrontendImage=ghcr.io%2Fcollective%2Fplone-in-a-box-frontend%3A19-juizi-dashboard&param_DemoUser=demo)
[![Deploy on Linode](https://img.shields.io/badge/Deploy%20on-Linode-00a95c?logo=akamai&logoColor=white&style=for-the-badge)](https://cloud.linode.com/stackscripts/2318969)

What it takes:

1. **An image with your add-on** (if it has a Volto part): one entry in Plone in a Box's
   [image list](frontend-image/README.md) names your npm and Python packages, and the roles a demo login needs to
   try it, for example `Editor`. A backend-only add-on skips this and names its Python package instead.
2. **The buttons:** the AWS one is a Launch Stack link with your image filled in, nothing to set up. The Linode one
   opens a small public StackScript for your add-on, which
   [`scripts/linode-addon-stackscript.sh`](scripts/linode-addon-stackscript.sh) writes for you; it always runs the
   latest Plone in a Box release, so it needs no updates.
3. **Your README:** paste the buttons, two short steps, and what the demo login can do.

The [Try it guide](docs/try-it-buttons.md) has each step, the Markdown to copy, and DigitalOcean and Hetzner, which
have no button. Ask in [collective/plone-in-a-box](https://github.com/collective/plone-in-a-box/issues) if you'd like
your add-on's image built there.

## For developers and system administrators

AWS, DigitalOcean and Hetzner can also be set up with Terraform from [`src/aws/`](src/aws/main.tf),
[`src/digitalocean/`](src/digitalocean/main.tf) and [`src/hetzner/`](src/hetzner/main.tf). They run the same
provisioning script as the console routes,
[`src/StackScript`](src/StackScript), which is also the Linode StackScript.

```
cd src/aws            # or src/digitalocean with DIGITALOCEAN_TOKEN set, or src/hetzner with HCLOUD_TOKEN set
terraform init
terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub' -var 'admin_password=...'
```

See the variables at the top of each `main.tf` for region, size, domain, versions and
backend add-ons, and the
[setup guide](docs/setup-guide.md#terraform-deployment-automated-more-technical) for account setup. Pass the same `-var` options to
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
