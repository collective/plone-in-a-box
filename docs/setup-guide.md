# Setting up your Plone in a Box™

This guide takes you from a cloud account to a running Plone 6 site, on Linode, Amazon AWS or DigitalOcean. Allow about 20 minutes,
most of it waiting for the server to provision.

What you get: one Ubuntu 26.04 LTS server running Plone 6.2 (backend), Volto 19 (the React front end) and PostgreSQL in
Docker, behind nginx. Only SSH (22), HTTP (80) and HTTPS (443) are open to the internet. You choose the Plone `admin`
password when deploying, or one is generated for you; there is no `admin`/`admin` login.

## Choosing a provider

Plone in a Box works the same on all four; the differences are in how you set it up and what it costs.

| | Linode (Akamai) | DigitalOcean | Amazon AWS | Hetzner |
|---|---|---|---|---|
| Setting it up | Easiest: a form with labelled fields for the password, domain and versions | Paste the launcher script and set the password in it | Easy: the Launch Stack button opens a form like Linode's | Paste the launcher script and set the password in it, like DigitalOcean |
| Smallest server for a small site | 1 GB (Nanode) | 1 GB Droplet | `t3.small` (2 GB) | 1 GB (CPX02) |
| Monthly cost of that server | Among the lowest | About the same as Linode | Noticeably higher | About the same as Linode |
| Address for a domain name | Fixed | Fixed | Fixed (the stack adds an Elastic IP) | Fixed |
| Browser console for the password | LISH Console | Droplet Console | EC2 Instance Connect | Console |
| Pricing | [linode.com/pricing](https://www.linode.com/pricing/) | [digitalocean.com/pricing](https://www.digitalocean.com/pricing) | [aws.amazon.com/ec2/pricing](https://aws.amazon.com/ec2/pricing/) | [hetzner.com/cloud](https://www.hetzner.com/cloud/) |

If you don't already use one of them, choose Linode. Choose DigitalOcean or AWS if you, or your organization,
already has an account and billing set up there. Choose Hetzner if you prefer a European provider; most of its
locations are in Germany and Finland. All four offer automatic server backups for an extra charge; see
**Backups** under [Day-to-day administration](#day-to-day-administration).

## Before you start

* **An SSH key.** On a Mac or Linux, check with `ls ~/.ssh/*.pub`. If nothing is listed, create one with
  `ssh-keygen -t ed25519`.
* **Server size.** On Linode and DigitalOcean, a 1 GB server (a Nanode, or the `s-1vcpu-1gb` Droplet) is enough
  for a small site. On AWS, use at least `t3.small` (2 GB). On small servers, setup adds a 2 GB swap file, and in
  testing with Plone 6.2 and Volto 19 some of the site's memory (about 150 to 350 MB) moved to it. Editing and
  images worked normally, but the first page after an idle spell can be a little slower while it's read back from
  swap. Choose 2 GB or more for a busier site.
* **A domain name (optional).** For HTTPS, create a DNS `A` record pointing at the server's IP address *before*
  provisioning, or add HTTPS later (see [Adding a domain later](#adding-a-domain-later)).

## Option A: Linode

1. Log in to [Cloud Manager](https://cloud.linode.com) and open the
   [Plone in a Box StackScript](https://cloud.linode.com/stackscripts/931893). (Or open **StackScripts → Community
   StackScripts** and search for **Plone in a Box** by **nguyen-plone**.)
2. Click **Deploy New Linode**.
3. Fill in the **StackScript Options** (all optional):
   * **Plone admin password**: at least 12 characters. If you set it, you won't need SSH at all. If you leave it
     empty (or it's too short), a password is generated and saved on the server.
   * **Domain name** and **Email for Lets Encrypt**: both are needed for HTTPS.
   * **Site time zone**, for example `America/Chicago` (default `UTC`).
   * **Site language**, a language code such as `en` (the default), `de`, `fr`, `es` or `pt-br`, and **Starter
     content**: `yes` (the default) creates the sample pages a new site, or a [Plone distribution](#custom-backend-image),
     comes with; `no` starts with an empty site.
   * **Plone backend image tag** and **Volto frontend image tag** (defaults `6.2` and `19`).
   * **Backend add-ons**, for example `collective.easyform` (see [Add-ons](#add-ons)).
   * **Frontend image**, for example `ghcr.io/collective/plone-in-a-box-frontend:19-vlt` for Volto Light Theme
     (see [Themes and frontend images](#themes-and-frontend-images)).
   * **Demo login**, its password and its roles: an extra login, for example `demo`, for people you let try the site (see
     [Demo login](#demo-login)).
   * **Automatic updates**: `yes` (the default) installs Plone, Volto and PostgreSQL patch releases every week; see
     [Updates](#updates).
   * **Notification URL**, where update reports go, for example `https://ntfy.sh/<a long random topic>`; see
     [Updates](#updates).
   * **Email** settings, so the site can send email (password resets, forms, update reports) through an email relay
     service; see [Sending email](#sending-email).
4. Choose **Ubuntu 26.04 LTS** as the image (24.04 also works), a region, and a plan: a 1 GB **Nanode** is enough
   for a small site, 2 GB or more for a busier one.
5. Set a root password, add your **SSH key**, and click **Create Linode**.

Cloud Manager asks you to choose a **Public Interface Firewall**. Pick **No firewall** if it's offered (the server runs
its own firewall, ufw, which allows only ports 22, 80 and 443). Otherwise create one named `plone-in-a-box` and reuse it
for every deploy: default inbound policy **Drop**, default outbound **Accept**, and three inbound **Accept** rules for
TCP ports **22**, **80** and **443** from all IPv4 and IPv6 addresses. A firewall without those rules blocks both SSH
and the site. If you set the outbound policy to **Drop** instead, see [Outgoing connections](#outgoing-connections).

Once the Linode shows *Running*, open `http://<linode-ip>` in your browser. Within a minute or two it shows a
**"Your Plone site is being set up"** page that lists each step and refreshes itself; when setup is done (usually about
10 minutes), the next refresh shows your Plone site. If you set an admin password, log in as `admin` and you're done;
skip to step 2 of [After provisioning](#after-provisioning). Otherwise continue with step 1 using `ssh root@<linode-ip>`.
If the page says **"Setup didn't finish"**, see [Troubleshooting](#troubleshooting).

## Option B: Amazon AWS

Use the AWS console, with no command line ([Console deployment](#console-deployment-easiest)), or Terraform
([Terraform deployment](#terraform-deployment-automated-more-technical)).

### Console deployment (easiest)

No command line is needed.

1. Sign in to the [AWS console](https://console.aws.amazon.com/). A new AWS account works as is.
2. Click [**Launch Stack**](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https%3A%2F%2Fplone-in-a-box-templates.s3.us-east-1.amazonaws.com%2Flatest%2Fcloudformation.yaml&stackName=plone-in-a-box). It opens CloudFormation's **Quick create stack** page in N. Virginia
   (us-east-1); to use another region, switch it at the top right of that page before continuing.
3. Fill in the form:
   * **Plone admin password** (required, at least 12 characters).
   * **Site time zone**, **Site language** and **Starter content** (as for Linode above), **Server size** (default `t3.small`, the smallest that runs Plone well) and **Disk size**.
   * **Domain name** and **Email for Let's Encrypt**, if you want HTTPS and your domain's DNS already points to the
     server. You can also add HTTPS later.
   * **SSH key pair** and **Allow SSH from**: optional, only if you want to log in from your own computer.
   * **Backend add-ons** and **Frontend image**: optional (see [Add-ons](#add-ons) and
     [Themes and frontend images](#themes-and-frontend-images)).
   * **Automatic updates**: `yes` (the default) installs patch releases every week, and **Notification URL**, where
     reports about them go; see [Updates](#updates).
   * **Email (optional)**: your email relay service's settings, so the site can send email; see
     [Sending email](#sending-email).
   * Leave the **Advanced** settings as they are.
4. Click **Create stack**. After a minute or two the stack shows `CREATE_COMPLETE`.
5. Open the **Outputs** tab and click the **SiteURL**. You'll see the setup progress page, which turns into your
   Plone site when it's ready (about 10 minutes). Log in as `admin` with the password you chose.

The stack creates a server, a firewall (security group) allowing ports 22, 80 and 443, and a fixed IP address (Elastic
IP), so the address stays the same if you stop and start the server. **PublicIP** on the Outputs tab is the address to
point a domain at. Forgot the password? Open **InstanceConnect** on the Outputs tab, click **Connect**, and run
`sudo cat /root/plone-credentials.txt` or `sudo plone-reset-admin-password`.

The server is protected from being deleted by mistake: AWS refuses to terminate it, also when the stack is deleted,
and deleting the stack keeps the Elastic IP. Don't use **Update** on the stack: every update looks up the newest
Ubuntu image, so it builds a new, empty server and moves the address to it (the old server is kept, and you can
move the Elastic IP back to it). Change settings on the server instead; it keeps itself current with `plone-update`.
To remove everything, see [Removing the box](#removing-the-box).

#### Or launch the server yourself

If you'd rather not use CloudFormation, you can launch the server in the EC2 console yourself. Pick a region, then
**EC2 → Launch instance**:

1. **Name**: for example `plone-in-a-box`.
2. **Application and OS Images**: **Ubuntu**, then **Ubuntu Server 26.04 LTS** (64-bit x86, or 64-bit Arm with a
   `t4g` instance type).
3. **Instance type**: `t3.small` (2 GB) or larger.
4. **Key pair**: choose or create one, so you can also log in with SSH.
5. **Network settings**: keep **Create security group**, allow **SSH traffic** from **Anywhere** (needed for the
   browser console in step 9; choose **My IP** if you'll only use SSH), and check **Allow HTTPS traffic from the
   internet** and **Allow HTTP traffic from the internet**.
6. **Configure storage**: change the default 8 GiB to **20 GiB** (gp3). 8 GiB is too small for the Docker images.
7. **Advanced details → User data**: paste the contents of
   [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh). **Set the admin password on
   the first setting line**, then the optional domain and Let's Encrypt email (for HTTPS), time zone, versions and
   add-ons. Keep each value inside its single quotes.
8. **Launch instance**. Open the instance's **Public IPv4 address** (`http://` at first; the site moves to `https://` when it's ready) to watch the setup progress
   page, which turns into your Plone site when it's ready.
9. Forgot to set the password? You still don't need SSH: select the instance, choose **Connect → EC2 Instance
   Connect** (user `ubuntu`), and run `sudo cat /root/plone-credentials.txt` to read the generated one, or
   `sudo plone-reset-admin-password` to choose a new one.

The public address changes if you stop and start the instance. Before pointing a domain at it, give it a fixed
address: **EC2 → Elastic IPs → Allocate**, then **Associate** it with the instance.

### Terraform deployment (automated, more technical)

#### One-time setup

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

#### Deploy

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
# site_language     = "de"
# starter_content   = false
# backups           = true  # daily disk snapshots, the newest 7 kept (extra cost); see Backups
# addons            = "collective.easyform"
# frontend_image    = "ghcr.io/collective/plone-in-a-box-frontend:19-vlt"
# demo_user         = "demo"   # demo_roles = "Editor"; by default the image's suggestion, or Site Administrator
# auto_update       = false  # weekly patch releases are on by default
# notify_url        = "https://ntfy.sh/a-long-random-topic"
# smtp_host         = "mail.smtp2go.com"  # email, optional: see Sending email
# smtp_user         = "..."
# smtp_password     = "..."
# email_from        = "plone@example.org"
# report_email      = "you@example.org"
# spamhaus_key      = "..."  # optional: see Blocklists
```

Other variables (region, instance type, SSH source addresses, versions, disk size) are described at the top of
`src/aws/main.tf`. The server downloads its setup script from the Plone in a Box release in `release` (the current
one by default), so edits to `src/StackScript` in your copy aren't used. To try changes, push them to a branch and
set `release` to it (in a fork, also change the GitHub address in `src/aws/main.tf`). The account needs a default VPC, which new AWS accounts have.

Type `yes` to confirm. Terraform prints `site_url`, `public_ip` and `credentials_command`. The server then provisions
itself. Open the `site_url` in your browser to watch the setup progress page, which turns into your site when it's
ready. Or follow the log:

```
ssh ubuntu@<public-ip> sudo tail -f /var/log/plone-in-a-box.log
```

It's done when you see `[plone-in-a-box] Finished.` Continue with [After provisioning](#after-provisioning) using
`ssh ubuntu@<public-ip>` and `sudo`.

## Option C: DigitalOcean

Use the DigitalOcean control panel, with no command line ([Console deployment](#console-deployment-easiest-1)), or
Terraform ([Terraform deployment](#terraform-deployment-automated-more-technical-1)).

### Console deployment (easiest)

No command line is needed if you set the admin password here. If you leave `CHANGE-ME` (or any password under 12
characters), a password is generated instead; see "Forgot to set the password?" below.

1. **Create → Droplets**, choose **Ubuntu 26.04 (LTS) x64**, a 1 GB or larger size, and your SSH key.
2. Under **Additional Options**, choose **Startup scripts (free)** and paste these three lines into **Enter your
   scripts or data**. Replace `CHANGE-ME` with your admin password (at least 12 characters), keeping the quotes:
   ```
   #!/bin/bash
   export ADMIN_PASSWORD='CHANGE-ME'
   curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.24/src/StackScript && bash /root/plone-in-a-box.sh
   ```
   They download the provisioning script from a fixed Plone in a Box release and run it. For more settings (a
   domain and Let's Encrypt email for HTTPS, the time zone, versions, add-ons, a theme), paste the contents of [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh) instead,
   and fill in its setting lines.
3. Create the Droplet. If you add a Cloud Firewall, allow inbound TCP 22, 80 and 443. (The server's own firewall
   allows only those ports either way.)
4. Open the Droplet's address to watch the setup progress page, which turns into your Plone site when it's ready.

Forgot to set the password? You still don't need SSH: open the Droplet in the control panel, choose **Access →
Launch Droplet Console**, and run `cat /root/plone-credentials.txt` to read the generated one, or
`plone-reset-admin-password` to choose a new one.

### Terraform deployment (automated, more technical)

1. Install Terraform (see [One-time setup](#one-time-setup) under AWS) and create an API token: in the DigitalOcean control panel, go to **API →
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

   Options go in `src/digitalocean/terraform.tfvars` the same way as for AWS. Variables include `size` (default
   `s-1vcpu-2gb`), `region`, `preferred_regions`, `backups`, `domain`, `letsencrypt_email`, `site_timezone` and the
   versions. Unlike AWS, where the default server type is offered in every region, DigitalOcean's regions don't all
   offer every size, and that changes over time as they fill up. With `region` empty (the default),
   Terraform picks the first region in `preferred_regions` that offers the size (Toronto, New York, San Francisco, then
   Amsterdam, Frankfurt, London; put your own part of the world first), and prints the one it chose. A `region` you
   set is always used; if it doesn't offer the size, `terraform apply` stops before creating anything and lists the
   regions that do. Once created, the Droplet stays in its region.
   As on AWS, the Droplet downloads its setup script from the Plone in a Box release in `release`, so to try
   changes, push them to a branch and set `release` to it.
3. Terraform prints `site_url`, `public_ip`, `region` and `credentials_command`. The Droplet also gets a DigitalOcean Cloud
   Firewall that allows only ports 22, 80 and 443.

Open the `site_url` to watch the setup progress page (or follow `ssh root@<public-ip> tail -f
/var/log/plone-in-a-box.log`), then continue with [After provisioning](#after-provisioning).

## Option D: Hetzner

Use the Hetzner Console, with no command line ([Console deployment](#console-deployment-easiest-2)), or
Terraform ([Terraform deployment](#terraform-deployment-automated-more-technical-2)). Hetzner organizes servers in
projects; use an existing one, or create one (for example `plone`) with **+ New project**.

### Console deployment (easiest)

No command line is needed if you choose the admin password here. In the
[Hetzner Console](https://console.hetzner.com), open your project and click **Create server**:

1. **Type**: under **Shared Resources**, choose **Regular Performance** and **CPX02** (1 vCPU, 1 GB), which is enough
   for a small site, as on Linode and DigitalOcean; CPX12 (2 GB) or larger for a busier one. CPX02 isn't offered in
   the US locations; there, choose **CPX11** (2 GB). Arm plans (**Cost-Optimized**, such as CAX11) work too, in the
   German and Finnish locations that have them in stock.
2. **Location**: Nuremberg, Falkenstein or Helsinki in Europe; Ashburn or Hillsboro in the US; or Singapore (which
   costs a little more).
3. **Image**: on the **OS Images** tab, **Ubuntu**, with **26.04** chosen in its version menu.
4. **Networking**: keep **Public IPv4** and **Public IPv6** ticked. You need the IPv4 address to open the site (Hetzner
   charges a little extra for it).
5. **SSH keys**: add yours if you want to log in from your own computer. Without one, Hetzner emails you a root
   password, which you'd only need for the browser console.
6. **Firewalls** are optional. If you add one, allow inbound TCP 22, 80 and 443. (The server's own firewall allows
   only those ports either way.) **Backups** are optional too, for 20% of the server's price.
7. **Cloud config**: paste these three lines into the box (it says "Cloud-init configuration"). Replace `CHANGE-ME`
   with your admin password (at least 12 characters), keeping the quotes:
   ```
   #!/bin/bash
   export ADMIN_PASSWORD='CHANGE-ME'
   curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.24/src/StackScript && bash /root/plone-in-a-box.sh
   ```
   For more settings (a domain and Let's Encrypt email for HTTPS, the time zone, versions, add-ons, a theme), paste the contents of
   [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh) instead, and fill in its setting lines.
8. **Name** is filled in for you; change it if you like (for example `plone`). Click **Create & Buy now**, then open
   the server's IPv4 address (with `http://`) to watch the setup progress page, which turns into your Plone site
   when it's ready.

Forgot to set the password? You still don't need SSH: open the server and click the **Console** button (`>_`) at the
top right. Log in as `root` (with the password Hetzner emailed you, or after **Rescue → Reset Root Password**), and run
`cat /root/plone-credentials.txt` to read the generated one, or `plone-reset-admin-password` to choose a new one.

The server keeps its IPv4 address (a Primary IP) for as long as it exists, so you can point a domain at it.

### Terraform deployment (automated, more technical)

1. Install Terraform (see [One-time setup](#one-time-setup) under AWS) and create an API token: in your Hetzner
   project, go to **Security → API tokens → Generate API token**, choose **Read & Write**, and copy it. It's shown
   only once, and it only works for that project.
2. Deploy:
   ```
   export HCLOUD_TOKEN=<your token>
   git clone https://github.com/tkimnguyen/plone-in-a-box
   cd plone-in-a-box/src/hetzner
   terraform init
   terraform apply -var 'ssh_public_key_path=~/.ssh/id_ed25519.pub'
   ```
   Options go in `src/hetzner/terraform.tfvars` the same way as for AWS. Variables include `server_type` (default
   `cpx02`, 1 GB; `cpx11` in `ash` and `hil`; Arm types such as `cax11` work too), `location`, `preferred_locations`,
   `backups`, `domain`, `letsencrypt_email`, `site_timezone` and the versions. As on DigitalOcean, not every location
   offers every server type, and a type can run out in a location for a while. With `location` empty (the default), Terraform picks the first location in `preferred_locations` that
   offers the server type (Helsinki, Falkenstein, Nuremberg) and prints the one it chose. A `location` you set is
   always used; if it doesn't offer the server type, `terraform apply` stops before creating anything and lists the
   locations that do. Once created, the server stays in its location. As on AWS, the server downloads its
   setup script from the Plone in a Box release in `release`, so to try changes, push them to a branch and set
   `release` to it.
3. Terraform prints `site_url`, `public_ip`, `location` and `credentials_command`. The server also gets a Hetzner Firewall that
   allows only ports 22, 80 and 443.

Open the `site_url` to watch the setup progress page (or follow `ssh root@<public-ip> tail -f
/var/log/plone-in-a-box.log`), then continue with [After provisioning](#after-provisioning).

### Changing a Terraform server later

This applies to AWS, DigitalOcean and Hetzner. Most owners never run Terraform again: the server keeps itself
current with `plone-update` (see [Updates](#updates)), and everything else is done on the server. You might come
back to the same `src/<provider>/` folder to:

* **Change who can use SSH** (`ssh_allowed_cidrs`), **turn the provider's backups on or off** (`backups`), or
  **resize the server** (`instance_type` and `volume_size_gb` on AWS, `size` on DigitalOcean, `server_type` on
  Hetzner). Run `terraform apply` with the new value; Terraform changes these on the existing server (resizing
  restarts it).
* **See the site address and other outputs again**: `terraform output`.
* **Remove the box**: see [Removing the box](#removing-the-box).

The other settings (the admin password, domain, versions, add-ons, email, `release`, the region or location, the
SSH key) and the Ubuntu image are used only when the server is created. Changing them later does nothing to the
existing server. Neither does `git pull` to get a newer Plone in a Box and running `terraform apply` again: that
doesn't update the server (`plone-update` does), and it can't rebuild it, which would start an empty site.

Terraform also never deletes the server: `terraform destroy`, and any change that would need a new server, stop
with an error. On AWS and Hetzner the provider refuses too (termination protection, and delete and rebuild
protection), also in its web console. To remove a box on purpose, see [Removing the box](#removing-the-box).

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

   `admin` is a Zope-level user, so its password isn't changed in Site Setup. To change it, or if you've forgotten
   it, log in to the server and run:
   ```
   sudo plone-reset-admin-password
   ```
   It asks for the new password (or press Enter to have one generated). The change takes effect immediately. To run
   it straight from your computer, use `ssh -t` so it can prompt you: `ssh -t root@<server> plone-reset-admin-password`.
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
```

For updates, see [Updates](#updates).

**SSH**: if the server has an SSH key (you chose one when creating it), setup turns password logins off, for root
too: logging in takes the key. A server created with only a password keeps password logins, so you can still get in;
the credentials file says so. To turn them off later, add your public key to `/root/.ssh/authorized_keys` (or the
default user's, such as `ubuntu` on AWS), check that you can log in with it, and then:

```
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' \
  | sudo tee /etc/ssh/sshd_config.d/00-plone-in-a-box.conf
sudo sshd -t && sudo systemctl reload ssh
```

Either way, fail2ban blocks an address for an hour after 5 failed logins in 10 minutes, longer each time it comes
back. If it blocks you, log in from the provider's browser console, and `sudo fail2ban-client set sshd unbanip
<your address>`.

**Backups**: every night, the server saves a database backup in `/var/backups/plone/`. The three newest are kept,
counting those taken before updates, and each one is the whole site, files and images included. Once a week it
also packs the database: it removes the history of changes older than a week, which would otherwise make the
database grow forever. `sudo plone-backup` runs both now (`sudo plone-backup pack` packs as well), and the log is in
`/var/log/plone-backup.log`. If a backup fails, a notice goes to the notification URL and by email, and if backups
stop without failing (a stopped timer, say), the weekly update report says the newest backup is more than two days
old. The nightly backup also checks the disk: once it's over 85% full, you get a notice (and another at every 5
points more), and the weekly report says so until there's room again.

**When a tool stops**: the backups, updates, security notices and nightly restarts report the problems they find
themselves. If one of them is stopped instead (it ran out of time or memory, or crashed), a notice says so, with its
last log lines.

Next to each database backup, `plone-<date>.config.tar.gz` holds the server's own settings: `/opt/plone/.env`
(versions, images, add-ons), `/opt/plone/docker-compose.yml` and the nginx site. The site doesn't need them to
be restored, but they save redoing settings by hand on a new server: `tar -tzvf` lists what's inside.

These backups are on the same server, so they don't help if the server itself is lost. For that, send a copy of
each night's backup to storage elsewhere (below), turn on your provider's server backups (Linode Backups,
DigitalOcean Backups, EBS snapshots on AWS, or Hetzner Backups), or copy a backup somewhere else now and then:

```
scp root@<server>:/var/backups/plone/plone-<date>.sql.gz .
```

(On AWS, log in as `ubuntu` instead of `root`, and copy the file to your home directory with `sudo cp` first.)

**Server backups on AWS**: with Terraform, `backups = true` turns on daily snapshots of the server's disk through
AWS Data Lifecycle Manager, and keeps the newest 7. A server made with **Launch Stack** gets them with a policy you
make once in the AWS console:

1. **EC2 → Lifecycle Manager → Create lifecycle policy**, then **EBS snapshot policy**.
2. **Target resource types**: **Instance**. **Target resource tags**: key `Name`, value your stack's name (such as
   `plone-in-a-box`). **IAM role**: **Default role** (the console makes it if it doesn't exist yet).
3. **Schedule**: **Daily**, every **24 hours**, starting at `03:00` UTC (after the nightly database backup), with
   retention by **Count**, `7`. Leave the rest, and **Create policy**.

Snapshots are charged for the space they take (about US$0.05 a GB a month; after the first, each holds only what
changed), and appear in **EC2 → Snapshots**. To get a server back from one, see AWS's
[Restore from a snapshot](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-restoring-volume.html). Deleting the
policy stops new snapshots and leaves the ones taken.

**Copies off the server**: every night's backup can also go to S3-compatible storage, such as Cloudflare R2, AWS S3,
Backblaze B2, DigitalOcean Spaces or Hetzner Object Storage, encrypted on the server first, so a leaked bucket or key
doesn't expose your site. A small site's copies cost cents a month, or nothing within R2's and B2's free allowances;
R2 also charges nothing for downloading them again. At your storage service, create a **private** bucket and an
access key that can list, read, write and delete in that bucket only:

* **Cloudflare R2**: **R2 → Create bucket**, then **Manage API tokens → Create API token** with **Object Read &
  Write**, limited to that bucket. The endpoint is `https://<account-id>.r2.cloudflarestorage.com` (the account ID
  is on the R2 page), and the region is `auto`.
* **AWS S3**: **S3 → Create bucket** (keep **Block all public access** on), then an IAM user with an access key and
  this policy, with your bucket's name:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {"Effect": "Allow", "Action": ["s3:ListBucket"], "Resource": "arn:aws:s3:::<bucket>"},
      {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], "Resource": "arn:aws:s3:::<bucket>/*"}
    ]
  }
  ```

  The endpoint is `https://s3.<region>.amazonaws.com`, for example `https://s3.us-east-1.amazonaws.com`.

Then run:

```
sudo plone-offsite setup
```

It asks for the endpoint (it shows examples), region, bucket, the key, how many copies to keep (14 by default), and
a folder in the bucket (one per server, so several servers can share a bucket). It uploads and deletes a test file
to check them, then shows a **passphrase**: keep it in your password manager. The copies can't be read without it,
and if the server is lost, so is its copy of the passphrase. From then on, `plone-backup` encrypts each night's
backup, uploads it, and removes the oldest copies; if that fails, a notice goes to the notification URL.

To restore from a copy, on this server or a new one (run `sudo plone-offsite setup` there first, with the same
bucket and key, and paste the passphrase when it asks):

```
sudo plone-offsite list
sudo plone-offsite fetch <folder>/<name>
sudo plone-restore /var/backups/plone/offsite-<name>.sql.gz
```

`sudo plone-offsite off` stops making copies and leaves the bucket as it is.

**Restoring a backup** puts the whole site back as it was when the backup was taken: pages, files, users,
passwords and settings. `sudo plone-restore` lists the backups on the server, and

```
sudo plone-restore /var/backups/plone/plone-<date>.sql.gz
```

restores one after you type `yes`. It first saves a backup of the site as it is now
(`/var/backups/plone/before-restore-<date>.sql.gz`, kept until you delete it), and if the restore fails, it puts
that back. The site is down for a minute or two. Afterwards, log in with the passwords from the time of the
backup. The log is in `/var/log/plone-restore.log`.

**Moving a site to a new server** works the same way: set up the new server with Plone in a Box, with the same
Plone version as the old one (or newer, then run any upgrade steps in Site Setup), copy a backup to it, and restore
it there:

```
scp root@<old-server>:/var/backups/plone/plone-<date>.sql.gz root@<new-server>:/root/
ssh root@<new-server> plone-restore /root/plone-<date>.sql.gz
```

Then point your domain at the new server, and delete the old one when you're sure.

**Checking the backups**: a backup you've never restored may not restore. Once a month (the first Wednesday,
around 04:30 server time), `plone-backup-check.timer` loads the newest backup into a separate test database next
to the site's, has Plone open the site in it and read its newest pages and a file or image, and then deletes the
test database. The site keeps running and isn't touched. With [copies off the server](#day-to-day-administration),
it tests the newest copy there instead, downloaded and decrypted the way you would after losing the server, so the
passphrase and the bucket are checked too, and it warns if the newest copy is more than three days old. If
anything fails, a notice goes to the notification URL and by email, and the login message shows it until the next
check passes. `sudo plone-backup-check` runs it now (`sudo plone-backup-check <file>` tests one backup), and the
result of the last one is in `/var/lib/plone-in-a-box/backup-check`, the log in `/var/log/plone-backup-check.log`.
It needs free disk space for a second copy of the database while it runs.

A server set up before 2.16 gets the nightly backups with the [same command](#servers-set-up-before-212) as automatic
updates, and one set up before 2.19 gets `plone-restore` with it too (before 2.20, `plone-offsite`, and before 2.25,
`plone-backup-check`).

**Knowing when the site is down**: the server can't tell you that it's down itself, so let something outside check
the site's address every minute or so and alert you:

* **DigitalOcean Uptime** (**Monitoring → Uptime → Create Uptime Check**) can check any address, so it works for a
  site on Linode, AWS or Hetzner too. Choose type **HTTPS**, the site's address, and
  three regions. A check gets its alerts one at a time: add a **Downtime** alert set to **down in all regions** with
  a wait of 2 minutes (so a network problem near one region doesn't wake you), then use **Add alert** again for an
  **SSL certificate expiry** alert at 14 days, in case renewing the certificate stops working. Alerts only go to
  email addresses verified in the DigitalOcean account.
* **AWS**: a **Route 53 health check** on the site's address, with a CloudWatch alarm that emails you.
* Or an outside uptime service, many of which have a free plan.

Your provider can also tell you when the server itself is struggling:

* **Linode**: the Linode's **Alerts** tab (CPU, disk activity, network traffic and transfer quota, by email), and
  **Settings → Shutdown Watchdog**, which starts the Linode again if it powers off unexpectedly. Check once that
  both are on, and that your Linode profile's email address reaches you.
* **DigitalOcean**: install the metrics agent (`curl -sSL https://repos.insights.digitalocean.com/install.sh | sudo
  bash`; the Droplet's **Insights** tab then shows memory and disk use), and create **Monitoring → Resource Alerts**
  for disk use over 85%, memory over 90% for 10 minutes, and CPU over 90% for 30 minutes. Give the Droplets a tag and
  choose the tag, so a new server gets the same alerts.
* **AWS**: CloudWatch alarms on the instance's CPU and status checks. **Hetzner** Cloud has no alerts of this kind;
  an uptime check covers the most common problems.

**Outgoing connections**: setup doesn't limit what the server connects to. If you add a firewall in front of it that
does (a Linode Cloud Firewall with outbound policy **Drop**, say), allow these, or parts of the box stop working
without saying why:

| Port | For |
|---|---|
| TCP 443 and 80 | Ubuntu's updates, Docker images, Let's Encrypt, security notices, notifications, off-site backups |
| UDP and TCP 53 | DNS, unless the provider's resolver is inside its network |
| UDP 123 | the clock (NTP); without it the clock drifts, and HTTPS and logins can start failing |
| TCP 587 or 2525 | email, if the site sends it (see [Sending email](#sending-email)) |

## Updates

A box has two kinds of software, and each one updates differently.

**Ubuntu, nginx and Docker** come from Ubuntu's packages. Setup installs all updates and restarts the server once
if they need it. After that, Ubuntu installs security updates automatically every day, nginx's included. Some of
them, such as a new Linux kernel, only take effect after a restart, which Ubuntu doesn't do by itself, so the server
restarts at night when one is waiting: at 03:30 server time (usually UTC), after the nightly backup, and only once no
backup or update is running. The site is down for a minute or two, and Plone starts again by itself. Each restart is
logged in `/var/log/plone-reboot.log`; `sudo plone-reboot` restarts now if updates are waiting for it. To restart by
hand instead (the weekly report tells you when updates have waited more than two days):

```
sudo systemctl disable --now plone-reboot.timer
```

Ubuntu's automatic updates leave out Docker, which comes from Docker's own repository. Every month or so, run:

```
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Plone starts again by itself; the site is down for a minute or two. Don't run `do-release-upgrade` to move to a new
Ubuntu release: deploy a new server instead.

**Plone, Volto and PostgreSQL** run from Docker images. With **Automatic updates** on (the default), every Sunday
early in the morning (server time, usually UTC) the server installs newer images of the **same** versions: patch
releases and security fixes, such as Plone 6.2.2 to 6.2.3; moving to 6.3 is up to you. If there's anything new, it first
saves a database backup in `/var/backups/plone/` (the three newest are kept), then updates, and checks that the
site comes back. If it doesn't, it goes back to the previous images, and skips that build from then on. A
ready-made frontend image whose new build needs a different backend add-on is left for you to update (see
[Themes and frontend images](#themes-and-frontend-images)). The site is down for a minute or two during an update.

You hear about it in up to three places:

* **At the notification URL**, if you set one when you created the server. The easiest is
  [ntfy](https://ntfy.sh): install the ntfy app on your phone, subscribe to a topic with a long random name that
  only you know (anyone who knows it can read the messages), and use `https://ntfy.sh/<that topic>` as the
  **Notification URL**. An incoming webhook URL from Slack, Discord, Google Chat, Mattermost or Microsoft Teams
  works too, to post the reports in a team channel. For Teams, open the channel's **•••** menu, choose
  **Workflows**, pick **Send webhook alerts to a channel** (older Teams: **Post to a channel when a webhook
  request is received**), and copy the URL it shows at the end.
  Setup sends a first notice when the site is ready, so you know right away that it works. To change the URL later, edit `/var/lib/plone-in-a-box/notify-url` on the server (only root can read it).
* **By email**, if the site can send email through an email relay service (see [Sending email](#sending-email)):
  to the **Email for reports** chosen when creating the server, or else the site's From address, after anything
  but a week with nothing new.
* **In the login message**, when you log in to the server over SSH or in the browser console.

The report also says when a new Plone release is out, such as 6.3. Moving to it is up to you (see below).

To update right away, or on a server with automatic updates off:

```
sudo plone-update
```

To turn automatic updates off, or back on:

```
sudo systemctl disable --now plone-update.timer
sudo systemctl enable --now plone-update.timer
```

The log is in `/var/log/plone-update.log`.

### Security fixes and new Plone releases

Once a day the server checks the [Security category](https://community.plone.org/c/announcements/security) of the
Plone forum, where the Plone Security Team announces security fixes, often a week or so ahead. Each new post goes to
the same places as update reports: the notification URL, email, and the login message (for 30 days). Each post is
sent once, and a new server starts with the newest post, so it doesn't get the old ones.

When a post announces a **released** fix and automatic updates are on, the server doesn't wait for Sunday: it runs
`plone-update` the same day, so the fix is in within a day. If the Plone images with the fix aren't out yet (they
sometimes follow the announcement by a few hours), it tries again every day for a week. The notice says what
happened: installed, not out yet, or failed and undone. The site is down for a minute or two while an update
installs, during the day if that's when the post arrives.

Whether you need to do anything:

| What's announced | What the server does | What you do |
|---|---|---|
| A **pre-announcement** ("a fix comes out on Tuesday") | Sends the notice | Nothing. The server installs the fix within a day of its release. With automatic updates off, run `sudo plone-update` on that day. |
| A **fix in new Plone patch releases** (the usual case, such as 6.2.3 → 6.2.4) | Installs it the same day, or as soon as its images are out | Nothing. With automatic updates off, run `sudo plone-update`. |
| A **hotfix package** for Plone versions that don't get new releases | Sends the notice | Install it as a [backend add-on](#add-ons), as the post says, or upgrade Plone. Rare now: fixes usually come as new releases. |
| A **change to make** until a fix is out (turning a feature off, say) | Sends the notice | What the post says. |
| A **new Plone version** to move to (such as 6.3) | Says so in the weekly update report | When you're ready: [Upgrading to a new Plone version](#upgrading-to-a-new-plone-version). |
| **Patch releases** without a security announcement | Installs them on Sunday | Nothing. With automatic updates off, run `sudo plone-update` now and then. |

When the Plone version your site runs stops getting security fixes, you need to move to a newer one; the
notices don't tell you that yet, so keep an eye on Plone's release schedule.

To check for new posts now: `sudo plone-security-notices`. To turn the notices off (and with them the same-day
updates):

```
sudo systemctl disable --now plone-security-notices.timer
```

The log is in `/var/log/plone-security-notices.log`. To hear about every Plone release and announcement, not only
security, also subscribe to the forum's [Announcements](https://community.plone.org/c/announcements) category
(its bell icon, after logging in).

### Servers set up before 2.12

A server set up with an older Plone in a Box (2.0 or later) can get automatic updates too. Open its console
(Linode's **Launch LISH Console**, DigitalOcean's **Access → Launch Droplet Console**, AWS's **Connect → EC2
Instance Connect**, Hetzner's **Console**, or SSH) and run:

```
curl -fsSL https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.24/src/add-updates.sh | sudo bash
```

It installs `plone-update`, the weekly updates and the login message, exactly as setup does on a new server, and
then runs `sudo plone-update` once, so the site gets any patch releases it's missing (after a backup). To get the
reports at a notification URL, put it between `sudo` and `bash`:

```
curl -fsSL https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.24/src/add-updates.sh | sudo NOTIFY_URL=https://ntfy.sh/your-long-random-topic bash
```

`AUTO_UPDATE=no` in the same place installs `plone-update` without the weekly updates. Running the command again,
for example after a new Plone in a Box release, brings these tools up to date; the weekly updates stay on or off as
they were.

### Upgrading to a new Plone version

**A new Plone or Volto release** (6.2 to 6.3, Volto 19 to 20) can need content and add-on changes, so it isn't
automatic. Read the Plone upgrade notes, take a backup, change `PLONE_VERSION` and `VOLTO_VERSION` in
`/opt/plone/.env`, then run:

```
sudo docker compose --project-directory /opt/plone pull
sudo docker compose --project-directory /opt/plone up -d
```

Don't change `POSTGRES_VERSION` on an existing server: a new PostgreSQL major version can't read the old data
directory without a migration.

**Security fixes before a release:** the Plone security team sometimes publishes a fix as a hotfix package first,
named like `Products.PloneHotfixYYYYMMDD`. Add it to the backend add-ons (see [Add-ons](#add-ons)), and remove it
again after the next update includes the fix. Security announcements are at
[plone.org/security](https://plone.org/security).

## Add-ons

Backend add-ons are Python packages that add features to Plone, for example `collective.easyform` (forms). List them,
separated by spaces, in the **Backend add-ons** setting when you deploy (the `ADDONS` line in `src/user-data.sh`, or
the `addons` Terraform variable). A version can be pinned, for example `collective.easyform==4.2.0`. When the site is
up, log in as `admin` and activate each one in **Site Setup → Add-ons**.

The `plone/plone-backend` image installs them with pip each time the backend starts, held to the versions the Plone
release was tested with, so a restart takes a little longer with add-ons. Setup tries the install first: if a name
is misspelled or a package doesn't work with this Plone version, the site is set up without the add-ons, and
`/root/plone-credentials.txt` and `/var/log/plone-in-a-box.log` say why.

To add or remove add-ons later, edit the `ADDONS='...'` line in `/opt/plone/.env` (deactivate an add-on in Site
Setup before removing it), then restart the backend:

```
sudo docker compose --project-directory /opt/plone up -d backend
sudo docker compose --project-directory /opt/plone logs -f backend   # watch pip install them
```

This needs a server set up with Plone in a Box 2.10 or later. If the backend doesn't come back, the pip messages
in the log say why: fix or remove the name and run `up -d backend` again.

Only packages on PyPI work this way. For a package from GitHub, or your own code, use a
[custom backend image](#custom-backend-image). Volto (frontend) add-ons and themes are built into the frontend
image; see [Themes and frontend images](#themes-and-frontend-images).

## Themes and frontend images

The **Frontend image** setting replaces the standard Volto image (the `FRONTEND_IMAGE` line in `src/user-data.sh`, or
the `frontend_image` Terraform variable). Plone in a Box publishes ready-made images, rebuilt every week:

| Frontend image | What you get |
| --- | --- |
| `ghcr.io/collective/plone-in-a-box-frontend:19-vlt` | [Volto Light Theme](https://github.com/kitconcept/volto-light-theme) 8.1.4 on Volto 19 |
| `ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard` | [Juizi Dashboard](https://pypi.org/project/juizi.dashboard/) 1.0.0b3 (beta) on Volto 19: an activity record and dashboard for site administrators, in Site Setup → Activity. A demo login gets Editor and Site Activity Viewer |

A ready-made image brings its backend half: setup installs and activates the matching backend add-on (for Volto Light
Theme, `kitconcept.voltolighttheme`) and turns on its site settings. Edit the home page to find them: the logo,
colours, header and footer settings sit with the site's own fields.

The ready-made frontend images are built for x86 servers; on Hetzner's Arm servers (`cax…`) setup uses the
standard Volto image. (The Aurora backend image, `ghcr.io/collective/plone-in-a-box-backend:6.2-aurora`, is built for
both.)

If the image can't be pulled (a typo, a private image, or no build for the server's processor), its backend
add-on can't be installed, or it doesn't start (built for another Volto version, say), the site is set up with the
standard Volto image instead, and `/root/plone-credentials.txt` and `/var/log/plone-in-a-box.log` say
why.

You can also give the name of an image you built yourself, with other Volto add-ons: fork this repository, add
your add-ons to one file, and GitHub builds and publishes the image for you. See
[Building your own](../frontend-image/README.md#building-your-own). It has to be public: setup can't log in to a
registry. When a frontend image is set, `VOLTO_VERSION` doesn't apply to the frontend; the image's
tag decides.

To change the frontend image on an existing server, edit the `FRONTEND_IMAGE='...'` line in `/opt/plone/.env`, then:

```
sudo docker compose --project-directory /opt/plone up -d frontend
```

This needs a server set up with Plone in a Box 2.11 or later. Changing it this way doesn't install the image's
backend add-on: add it to `ADDONS` (see [Add-ons](#add-ons)), activate it in Site Setup → Add-ons, and enable its
behaviors under Site Setup → Content Types → Plone Site → Behaviors.

## Demo login

The **Demo login** setting creates a second login on the site, for people you let try it: a client looking at a
draft site, or someone trying an add-on. Give it a username, for example `demo` (the `DEMO_USER` line in
`src/user-data.sh`, the `DemoUser` parameter, or the `demo_user` Terraform variable).

Its roles (`DEMO_ROLES`, `DemoRoles`, `demo_roles`) are one or more role names separated by commas, for example
`Editor` or `Editor, Reviewer`: **Site Administrator**, **Editor**, **Contributor**, **Reviewer**, **Member**, or a
role an add-on adds. Left empty, it gets the roles the frontend image suggests (its
[`demo-roles` label](../frontend-image/README.md#how-setup-uses-an-image), for example Editor and Site Activity Viewer
for Juizi Dashboard), or Site Administrator. A role the site doesn't have, such as an add-on's that failed to
install, is skipped, and so is Manager. (2.13's single-role setting, `DEMO_ROLE`, still works when set to
another role than Site Administrator.)

If the site [sends email](#sending-email), the demo login gets **Editor** instead of Site Administrator: a Site
Administrator can change **Site Setup → Mail**, and so could make the site send the email service's password to
another server. The credentials file says so. If you need a second administrator on such a site, add a user in
**Site Setup → Users**, for someone you trust with the email account too.

Its password (`DEMO_PASSWORD`, `DemoPassword`, `demo_password`) is optional: enter one of at least 12 characters
to choose it, or leave it empty and setup generates one and saves it in `/root/plone-credentials.txt`, next to the
admin password:

```
Demo login: demo / 7Gq2v8xRmT4pLwZs9KcN (Editor, Site Activity Viewer)
```

A password you chose isn't saved on the server; that line then says `(the password you entered when deploying)`.
To read the file, open your provider's browser console and run `sudo cat /root/plone-credentials.txt`. Or log in as
`admin` and set the demo login's password in **Site Setup → Users**.

Share that username and password; whoever has them can do anything its roles allow. A Site Administrator can edit
and delete all content, change most site settings and manage the other users except `admin`. The demo login is an
ordinary Plone user: change its password, its roles, or remove it in **Site Setup → Users**. Setup creates it only
once, when the server is created; to add one later, add a user there.

Without a domain, the site is on HTTPS at its IP address (see [HTTPS](#https)), so the demo login's password
travels encrypted too.

Add-on authors can give their README a button that sets up a server with their add-on and a demo login; see
["Try It" buttons](try-it-buttons.md).

## Custom backend image

Most sites don't need one: the [Backend add-ons](#add-ons) setting installs any package from PyPI. A **Backend
image** replaces the official Plone backend with another one:

* a **Plone distribution**, a whole kind of site ready to use, such as kitconcept's intranet, usually published as
  a backend image with a matching frontend image;
* your **own project**, for example one made with [cookieplone](https://github.com/plone/cookieplone), or the
  official image with packages that aren't on PyPI.

Set **Backend image** when you create the server: in the Linode form, the Launch Stack form, `backend_image` in
Terraform, or `export BACKEND_IMAGE='...'` in the launcher. Set its frontend half as the **Frontend image**. For
example, kitconcept's intranet:

* **Backend image**: `ghcr.io/kitconcept/kitconcept-intranet-backend:3.11`
* **Frontend image**: `ghcr.io/kitconcept/kitconcept-intranet-frontend:3.11`

Setup pulls the image and checks that it runs Plone with the server's settings. If it can't be pulled (a typo,
or a private image without a [registry login](#private-images)), or doesn't run, the site starts with the official Plone backend instead, and the credentials
file says why. The site is created the image's way: a distribution sets up its own content and settings. Setup
asks for the **Site language**, the server's time zone, **Starter content** and no Solr search server (a box doesn't
have one), using the settings names the official image and Plone distributions read. kitconcept's intranet, for
example, comes with sample pages in German; set **Starter content** to `no` for an empty intranet.

The weekly update installs newer builds of the image's tag, so pick a tag that moves with patch releases (such as
`3.11`, not `3.11.0`), and goes back if the site doesn't come back, as for the official images. Moving to a new
Plone version is up to the image's maker: the update report doesn't suggest new Plone versions for a custom image.

**What an image needs**: it's built on the official `plone/plone-backend` image, or the same way (cookieplone
projects and kitconcept's images are): its entrypoint has the `create-site`, `run` and `pack` commands, it reads
`RELSTORAGE_DSN` for the database, it has a health check, and it listens on port 8080. Images for Linode,
DigitalOcean and AWS are `linux/amd64`; Hetzner's Arm servers need `linux/arm64`. The **Backend add-ons** setting
works on top of an image built on `plone/plone-backend`.

**Building your own** from the official image, for packages that aren't on PyPI:

```dockerfile
FROM plone/plone-backend:6.2
RUN /app/bin/pip install --no-cache-dir -c /app/constraints.txt \
    "git+https://github.com/<owner>/<package>.git@<tag or commit>"
```

Pin a tag or commit, so a rebuild installs the same code, and push the image to a registry, for example the GitHub
Container Registry:

```
docker login ghcr.io
docker buildx build --platform linux/amd64 --push -t ghcr.io/<you>/plone-backend:6.2 .
```

Then activate the package in **Site Setup → Add-ons**.

**On a server that's already running**, set `BACKEND_IMAGE='<image>'` in `/opt/plone/.env`, then:

```
sudo docker compose --project-directory /opt/plone up -d backend
```

The site and its content stay as they are; they live in the database, not in the image. Keep the image on the same
Plone version as the site, or newer: a site can't move back to an older Plone. Switching a running site to a
distribution's image doesn't turn it into that distribution; that only happens when a site is created. If the
image is private, run `sudo docker login ghcr.io` on the server first. To go back, set `BACKEND_IMAGE=''` and run
the same command.

### Private images

A private frontend or backend image needs a login to its registry. Fill in **Registry username** and **Registry
token** when you create the server: in the Linode form, the Launch Stack form, `registry_user` and `registry_token`
in Terraform, or `export REGISTRY_USER='...'` and `export REGISTRY_TOKEN='...'` in the launcher. Setup logs in to the
registry of each image (both images share the one login, so keep them in one registry, under one account), and the
credentials file says whether it worked. Docker keeps the login on the server, in `/root/.docker/config.json`, so
the weekly updates can pull new builds too; the token isn't logged anywhere else.

Use a token that can only read images:

* **GitHub (ghcr.io)**: your GitHub username, and a classic personal access token (**Settings → Developer settings →
  Personal access tokens → Tokens (classic)**) with only the `read:packages` scope.
* **Docker Hub**: your Docker Hub username, and a personal access token with **Read-only** access.
* **GitLab** and others: a deploy token or access token with only the registry read scope.

When the token expires or you replace it, log in again on the server: `sudo docker login ghcr.io` (or the other
registry), with the same username and the new token.

## Sending email

A new site can't send email yet: password resets, form notifications and the update reports by email all need a
mail server. Cloud providers block sending email straight from a server (port 25), and mail sent that way usually
lands in spam anyway, so the site sends through an email relay service instead.

You need a domain of your own for this: the site's "From" address uses it, and the service asks you to add a few
DNS records (SPF and DKIM) at your domain host, so that receiving mail servers trust the mail. Also add a DMARC
record if the domain doesn't have one yet: a TXT record named `_dmarc` (or `_dmarc.<subdomain>` for a subdomain)
with the content `v=DMARC1; p=none`. Gmail and Yahoo expect one. A site with only an IP address can't send email
reliably through any of these services.

### Choosing a service

All of these work with Plone over SMTP on port 587. A small site (password resets, a contact form) stays well
within the smaller free tiers.

| Service | SMTP server | Free tier | Paid plans from | Before you can send | Good for |
|---|---|---|---|---|---|
| [SMTP2GO](https://www.smtp2go.com) | `mail.smtp2go.com` | 1,000 a month (200 a day), no time limit | about $10–15 a month for 10,000 | Verify your domain (only 25 an hour until then) | Small sites; SMTP is its main product |
| [Brevo](https://www.brevo.com) | `smtp-relay.brevo.com` | 300 a day, no time limit | $9 a month for 5,000 | Brevo approves the account for sending; verify your domain | The largest free tier |
| [Mailgun](https://www.mailgun.com) | `smtp.mailgun.org` | 100 a day | $15 a month for 10,000 | Without a card on file, it only sends to up to 5 addresses you verify | Developers who already use it |
| [Amazon SES](https://aws.amazon.com/ses/) | `email-smtp.<region>.amazonaws.com` | None for new accounts | about $0.10–0.16 per 1,000 | Ask AWS to move the account out of the sandbox; verify your domain; create SMTP credentials | Organizations already on AWS; the cheapest at volume |
| [Postmark](https://postmarkapp.com) | `smtp.postmarkapp.com` | 100 a month, for testing | $15 a month for 10,000 | Verify your domain; Postmark reviews the account | The best record for reaching inboxes |
| [Resend](https://resend.com) | `smtp.resend.com` | 3,000 a month (100 a day) | $20 a month for 50,000 | Verify your domain | Developers |

Prices and free tiers as of November 2026; they change often, so check the service's pricing page. For most
sites, **SMTP2GO** or **Brevo** is the simplest start, and **Amazon SES** suits an organization that already uses
AWS. The username is usually one the service creates for SMTP, not your login: SES has separate SMTP credentials,
Postmark uses a server token as both username and password, and Resend uses the username `resend` with an API key as
the password.

If your cloud provider also blocks port 587, try 2525, which SMTP2GO, Mailgun and Postmark accept too. DigitalOcean
blocks 25, 465 and 587 on many accounts; its support can open 587 if you ask, usually within a day or two. A
firewall you add yourself may block them too (see [Outgoing connections](#outgoing-connections)).

### Setting it up

First, with the service:

1. Sign up, add your domain (or a subdomain such as `mail.example.org`), and add the DNS records it shows at your
   domain host, plus the DMARC record above. If your DNS is on Cloudflare, set these records to **DNS only** (grey
   cloud), not proxied. Wait until the service shows the domain as verified.
2. Create SMTP credentials, if the service has a separate step for that.

Then, **when you create the server**, fill in the email settings (the Linode form's **Email** fields, the Launch
Stack form's **Email (optional)** section, the `SMTP_*`, `EMAIL_FROM` and `REPORT_EMAIL` lines of
`src/user-data.sh`, or the Terraform `smtp_*`, `email_from` and `report_email` variables):

* **SMTP server** and **SMTP port** (587, or 2525 if 587 is blocked), and the **SMTP username** and **password**
  from the service.
* **From address**: the address the site sends from, at the verified domain, for example `plone@example.org`. It
  doesn't need a mailbox behind it.
* **Email for reports**: your own address. Setup sends a test email there, and the weekly
  [update reports](#updates) go there too. Empty: the From address.

Setup puts these settings into the site's **Site Setup → Mail**, and the credentials file and the first
notification say whether the test email went out. Check that it arrived (look in the spam folder too).

**On a server that's already running**, log in to the site as admin, go to **Site Setup → Mail**, and fill in
**SMTP server**, **SMTP port**, **ESMTP username**, **ESMTP password**, **Site 'From' name** and **Site 'From'
address**. To check it, use **Forgot your password?** on the login page for a user with your address. Update reports
go to the Site 'From' address, unless `/var/lib/plone-in-a-box/report-email` on the server names another one.

Either way, password resets and forms then send email. To change the settings later, use **Site Setup → Mail**.

### Blocklists

Receiving mail servers look up domains in public blocklists, and email from a listed domain, or with links to one,
tends to land in spam. Setup looks up the site's domain and the From address's domain in the Spamhaus domain list
and SURBL, and the server's IP address in Spamhaus ZEN and SpamCop: a cloud server's address can be on one from
whoever had it before. The credentials file says if any of them is listed, with the page that explains how to have it
removed. (A listed IP address doesn't affect email sent through an email service, whose own addresses receivers
judge; you may still prefer a new server.) The weekly [update](#updates) looks up the domains again, and the report
says if one has been listed since. Some lists don't answer queries through the big DNS resolvers that cloud
providers use; those are skipped, and the setup log says which.

**Spamhaus from any provider:** Spamhaus answers through Linode's resolvers, but not through Hetzner's or
DigitalOcean's, for example. A free [Data Query Service key](https://www.spamhaus.com/data-access/free-data-query-service/)
(for non-commercial, low-volume use: register, then copy the key from section "1.0 Datafeed Query Service" of your
account) lets the checks ask Spamhaus from anywhere. Give it as the **Spamhaus DQS key** when you create the server
(`SpamhausKey` in the Launch Stack form, `spamhaus_key` in Terraform, `export SPAMHAUS_KEY='...'` in the launcher).
Only root can read it on the server, in `/var/lib/plone-in-a-box/spamhaus-key`; to add or change it later:

```
sudo sh -c 'umask 077; echo YOUR-KEY > /var/lib/plone-in-a-box/spamhaus-key'
```

If the key doesn't work, the credentials file says so, and the checks skip Spamhaus.

## HTTPS

Every site is on HTTPS, so passwords and everything else travel encrypted:

* **With a domain name** (and the Let's Encrypt email), setup gets a certificate for the domain, and the site is
  at `https://<domain>`.
* **Without one**, setup gets a certificate for the server's IP address, and the site is at `https://<ip>`. These
  certificates last about six days, so the server renews them by itself twice a day (`plone-https-ip.timer`), and
  a notice goes to the notification URL if renewing keeps failing. Visitors who type `http://` are sent to
  `https://`. The log is in `/var/log/plone-https-ip.log`; `sudo plone-https-ip` renews now, and
  `sudo plone-https-ip off` goes back to plain HTTP. (IPv4 only, for now: the IPv6 address stays on HTTP.)

If getting the certificate fails during setup (Let's Encrypt can't be reached, say), the site starts on HTTP and
the server tries again twice a day.

### Adding a domain later

Point your domain's DNS at the server, wait until `dig +short <domain>` shows the server's IP, then:

```
sudo plone-https-ip off
sudo sed -i 's/server_name _;/server_name <domain>;/' /etc/nginx/sites-available/plone
sudo systemctl reload nginx
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx --redirect -d <domain> -m <your-email> --agree-tos
echo 'https://<domain>' | sudo tee /var/lib/plone-in-a-box/site-url
```

The first line turns the IP address certificate off (on a server set up before 2.21, which doesn't have one, skip
it); the last makes update reports name the new address.

### Behind Cloudflare

If your domain's DNS is on Cloudflare, its proxy (the orange cloud) can stand in front of the site: Cloudflare
answers visitors, caches images and files, and absorbs attacks, and only it talks to your server. The server
should then accept web traffic only from Cloudflare, or anyone who finds its IP address can go around it. Once the
site works through Cloudflare:

1. In Cloudflare, **SSL/TLS → Overview**: set the mode to **Full (strict)** (the server has its own Let's Encrypt
   certificate, so Cloudflare can check it).
2. On the server:

   ```
   sudo plone-cloudflare on
   ```

   It first checks that the domain points at Cloudflare (otherwise nobody could visit the site, so it stops and
   says so). Then the firewall lets only Cloudflare's addresses reach ports 80 and 443, and nginx takes each
   visitor's own address from Cloudflare's `CF-Connecting-IP` header, so Plone's logs and forms see the visitor,
   not Cloudflare. SSH isn't affected.
3. Check that the certificate can still renew: `sudo certbot renew --dry-run`. If it fails, turn off **Always Use
   HTTPS** under **SSL/TLS → Edge Certificates** in Cloudflare, so Let's Encrypt's check on port 80 gets through.

Cloudflare publishes its addresses at [cloudflare.com/ips](https://www.cloudflare.com/ips/) and adds new ones now
and then; `plone-cloudflare.timer` updates the firewall from that list once a month, and a notice goes out if it
can't. `sudo plone-cloudflare status` shows whether it's on, and `sudo plone-cloudflare off` opens ports 80 and 443
to everyone again (do that before turning Cloudflare's proxy off). The log is in `/var/log/plone-cloudflare.log`.
A site without a domain name can't use it. A server set up before 2.25 gets the command with the
[same command](#servers-set-up-before-212) as automatic updates.

## Removing the box

* **Linode**: delete the Linode in Cloud Manager.
* **AWS**, **DigitalOcean** or **Hetzner** with Terraform: Terraform protects the server from being deleted, so
  removing it takes three steps, from `src/aws/`, `src/digitalocean/` or `src/hetzner/`, with the same `-var` options
  (or `terraform.tfvars`) and token as when you created it:
  1. On AWS and Hetzner only, turn the provider's protection off: `terraform apply -var deletion_protection=false`.
  2. In `main.tf`, change `prevent_destroy = true` to `prevent_destroy = false`.
  3. `terraform destroy` (on AWS and Hetzner: `terraform destroy -var deletion_protection=false`).
* **DigitalOcean** without Terraform: destroy the Droplet in the control panel.
* **AWS** with the Launch Stack button: the server is protected from being deleted, so:
  1. In **EC2 → Instances**, select the server, choose **Actions → Instance settings → Change termination
     protection**, untick **Enable** and save.
  2. In CloudFormation, select the stack and click **Delete**. That removes the server, its disk and the firewall.
  3. In **EC2 → Elastic IPs**, select the stack's address (named after the stack), then **Actions → Release Elastic
     IP addresses**. It's kept when the stack is deleted, so a mistake can't lose the site's address, and AWS
     charges for it until it's released.
* **AWS** launched yourself in EC2: terminate the instance, and release its Elastic IP if you allocated one.
* **Hetzner** without Terraform: delete the server in the Hetzner Console (**Delete** on the server's page).

If you used Terraform, delete the AWS access key, DigitalOcean API token or Hetzner API token when you no longer
need it.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `ssh: connect ... Operation timed out` on Linode | A Cloud Firewall is blocking port 22. Allow TCP 22, 80, 443, or detach it. |
| The server's clock is off, or updates, notifications or email fail with no clear reason | A firewall in front of the server blocks outgoing connections. See [Outgoing connections](#outgoing-connections). |
| Forgot the admin password | Log in to the server as root (SSH, or your provider's console: Linode **Launch LISH Console**, DigitalOcean **Access → Launch Droplet Console**, which needs no password; Hetzner **Console**) and run `sudo plone-reset-admin-password`, or `cat /root/plone-credentials.txt` if a password was generated and you never read it. Forgot the root password too? On Linode, power off and use **Reset Root Password**; on DigitalOcean, **Access → Reset root password**; on Hetzner, **Rescue → Reset Root Password**. |
| The page says "Setup didn't finish" | It shows which step failed. Usually a temporary download problem: delete the server and deploy again. To see details, log in as root and read `/var/log/plone-in-a-box.log`. |
| No setup page, or no `/root/plone-credentials.txt` after 15 minutes | Read `/var/log/plone-in-a-box.log` (or, if it's missing, `/var/log/cloud-init-output.log` on AWS, DigitalOcean and Hetzner), and check `sudo docker compose --project-directory /opt/plone ps`. |
| Terraform: `Value for undeclared variable` | You're running an old configuration. `git pull`, then `terraform init -upgrade` in `src/aws/`. |
| AWS console: the address doesn't load at all | The security group doesn't allow HTTP. Select the instance, **Security → Security groups → Edit inbound rules**, and add HTTP (80) and HTTPS (443) from `0.0.0.0/0`. Also make sure you opened `http://`, not `https://`. |
| AWS console: **EC2 Instance Connect** fails to connect | The security group only allows SSH from your IP. Allow SSH (22) from `0.0.0.0/0` (the server's own firewall still applies), or use SSH from your computer. |
| AWS Launch Stack: `No default VPC for this user` or `VPCIdNotSpecified` | The stack uses the region's default VPC. Switch to a region that has one (new accounts have one in every region), or create it under **VPC → Your VPCs → Actions → Create default VPC**. |
| DigitalOcean: `SSH Key is already in use on your account` | Pass `-var 'ssh_key_fingerprint=...'` with the existing key's fingerprint. |
| DigitalOcean: `Unable to authenticate you` | `DIGITALOCEAN_TOKEN` isn't set in this terminal, or the token lacks write scope. |
| DigitalOcean: `You are missing the required permission tag:create` (or another `...:create`) | The token has custom scopes. Create one with **Full Access**, export it, and run `terraform apply` again. |
| Hetzner: `unsupported location for server type` | That plan isn't offered in that location. Choose another plan or location; the Create server page shows which plans each location offers. In the US locations (`ash`, `hil`), use `cpx11`. |
| Hetzner: `SSH key with the same fingerprint already exists` (Terraform) | The key is already in the project. Delete it under **Security → SSH keys**, or use a different key. |
| Terraform: `no file exists at .../id_ed25519.pub` | Pass your key's path with `-var 'ssh_public_key_path=...'`, for `destroy` too. |
| Terraform on a Mac: `lookup sts.<region>.amazonaws.com: no such host` | Turn off iCloud Private Relay and retry. |
| The site has the standard look although a frontend image was set | Read `/root/plone-credentials.txt` and `grep -i frontend /var/log/plone-in-a-box.log`: setup uses the standard Volto image if the frontend image can't be pulled, its backend add-on can't be installed, or it doesn't start. See [Themes and frontend images](#themes-and-frontend-images). |
| An add-on isn't listed in **Site Setup → Add-ons** | Read `/root/plone-credentials.txt` and `grep add-ons /var/log/plone-in-a-box.log`: setup leaves the add-ons out if pip can't install them. Packages without an install profile don't appear there, since there's nothing to activate. See [Add-ons](#add-ons). |
| Linode: "A UDF is missing the required 'name' attribute" | The script was modified with a `<UDF>` tag that has no `name`. Use the current `src/StackScript`. |

Not listed here, or still stuck? Ask in the **[#plone-in-a-box](https://discord.com/channels/786421998426521600/903993234248835082)** channel on [the Plone Discord](https://discord.gg/jRrsnYkNvS), or
[open an issue](https://github.com/tkimnguyen/plone-in-a-box/issues).

The [2020 Plone Conference guide](archive/) describes the original Plone 5.2 version and is kept for reference.
