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
  provisioning, or add HTTPS later (see [Adding HTTPS later](#adding-https-later)).

## Option A: Linode

1. Log in to [Cloud Manager](https://cloud.linode.com) and open **StackScripts → Community StackScripts**.
2. Search for **Plone in a Box**, open it, and click **Deploy New Linode**.
3. Fill in the **StackScript Options** (all optional):
   * **Plone admin password**: at least 12 characters. If you set it, you won't need SSH at all. If you leave it
     empty (or it's too short), a password is generated and saved on the server.
   * **Domain name** and **Email for Lets Encrypt**: both are needed for HTTPS.
   * **Site time zone**, for example `America/Chicago` (default `UTC`).
   * **Plone backend image tag** and **Volto frontend image tag** (defaults `6.2` and `19`).
4. Choose **Ubuntu 26.04 LTS** as the image (24.04 also works), a region, and a plan: a 1 GB **Nanode** is enough
   for a small site, 2 GB or more for a busier one.
5. Set a root password, add your **SSH key**, and click **Create Linode**.

Cloud Manager asks you to choose a **Public Interface Firewall**. Pick **No firewall** if it's offered (the server runs
its own firewall, ufw, which allows only ports 22, 80 and 443). Otherwise create one named `plone-in-a-box` and reuse it
for every deploy: default inbound policy **Drop**, default outbound **Accept**, and three inbound **Accept** rules for
TCP ports **22**, **80** and **443** from all IPv4 and IPv6 addresses. A firewall without those rules blocks both SSH
and the site.

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
   * **Site time zone**, **Server size** (default `t3.small`, the smallest that runs Plone well) and **Disk size**.
   * **Domain name** and **Email for Let's Encrypt**, if you want HTTPS and your domain's DNS already points to the
     server. You can also add HTTPS later.
   * **SSH key pair** and **Allow SSH from**: optional, only if you want to log in from your own computer.
   * Leave the **Advanced** settings as they are.
4. Click **Create stack**. After a minute or two the stack shows `CREATE_COMPLETE`.
5. Open the **Outputs** tab and click the **SiteURL**. You'll see the setup progress page, which turns into your
   Plone site when it's ready (about 10 minutes). Log in as `admin` with the password you chose.

The stack creates a server, a firewall (security group) allowing ports 22, 80 and 443, and a fixed IP address (Elastic
IP), so the address stays the same if you stop and start the server. **PublicIP** on the Outputs tab is the address to
point a domain at. Forgot the password? Open **InstanceConnect** on the Outputs tab, click **Connect**, and run
`sudo cat /root/plone-credentials.txt` or `sudo plone-reset-admin-password`.

To remove everything, select the stack in CloudFormation and click **Delete**.

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
   the first setting line**, then the optional domain and Let's Encrypt email (for HTTPS), time zone and versions.
   Keep each value inside its single quotes.
8. **Launch instance**. Open the instance's **Public IPv4 address** (use `http://`) to watch the setup progress
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
```

Other variables (region, instance type, SSH source addresses, versions, disk size) are described at the top of
`src/aws/main.tf`. The account needs a default VPC, which new AWS accounts have.

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

No command line is needed if you choose the admin password here.

1. **Create → Droplets**, choose **Ubuntu 26.04 (LTS) x64**, a 1 GB or larger size, and your SSH key.
2. Under **Additional Options**, choose **Startup scripts (free)** and paste into **Enter your scripts or data** the contents of
   [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh).
   **Set the admin password on the first setting line**, then the optional domain and Let's Encrypt email (for
   HTTPS), time zone and versions. Keep each value inside its single quotes. This short script downloads the full provisioning script
   from a fixed Plone in a Box release and runs it.
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

   Options go in `src/digitalocean/terraform.tfvars` the same way as for AWS. Variables include `region` (default
   `nyc3`), `size` (default `s-1vcpu-2gb`), `backups`, `domain`, `letsencrypt_email`, `site_timezone` and the versions.
3. Terraform prints `site_url`, `public_ip` and `credentials_command`. The Droplet also gets a DigitalOcean Cloud
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
7. **Cloud config**: paste into the box (it says "Cloud-init configuration") the contents of
   [`src/user-data.sh`](https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/user-data.sh). **Set the admin password on the first
   setting line**, then the optional domain and Let's Encrypt email (for HTTPS), time zone and versions. Keep each
   value inside its single quotes.
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
   Options go in `src/hetzner/terraform.tfvars` the same way as for AWS. Variables include `location` (default
   `hel1`), `server_type` (default `cpx02`, 1 GB; `cpx11` in `ash` and `hil`; Arm types such as `cax11` work too),
   `backups`, `domain`, `letsencrypt_email`, `site_timezone` and the versions.
3. Terraform prints `site_url`, `public_ip` and `credentials_command`. The server also gets a Hetzner Firewall that
   allows only ports 22, 80 and 443.

Open the `site_url` to watch the setup progress page (or follow `ssh root@<public-ip> tail -f
/var/log/plone-in-a-box.log`), then continue with [After provisioning](#after-provisioning).

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
docker compose --project-directory /opt/plone pull              # fetch newer images of the same tags
docker compose --project-directory /opt/plone up -d             # apply them
```

To move to a newer Plone or Volto release, change `PLONE_VERSION` / `VOLTO_VERSION` in `/opt/plone/.env`, then
run `pull` and `up -d`. Read the Plone upgrade notes first, and take a backup. Don't change `POSTGRES_VERSION` on an
existing server: a new PostgreSQL major version can't read the old data directory without a migration.

**Ubuntu updates**: setup installs all updates and restarts the server once if they need it. Ubuntu then installs
security updates automatically, but never restarts by itself. Every month or so, and whenever the login message
says `*** System restart required ***`, run:

```
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Plone starts again by itself; the site is down for a minute or two. Don't run `do-release-upgrade` to move to a new
Ubuntu release: deploy a new server instead.

**Backups**: turn on your provider's server backups (Linode Backups, DigitalOcean Backups, EBS snapshots on AWS, or
Hetzner Backups), and/or dump the
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
* **AWS** with the Launch Stack button: in CloudFormation, select the stack and click **Delete**. That removes the
  server, its disk, the firewall and the fixed IP address.
* **AWS** launched yourself in EC2: terminate the instance, and release its Elastic IP if you allocated one.
* **Hetzner**: delete the server in the Hetzner Console (**Delete** on the server's page), or `terraform destroy` from
  `src/hetzner/` with the same `HCLOUD_TOKEN`.

If you used Terraform, delete the AWS access key, DigitalOcean API token or Hetzner API token when you no longer
need it.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `ssh: connect ... Operation timed out` on Linode | A Cloud Firewall is blocking port 22. Allow TCP 22, 80, 443, or detach it. |
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
| Linode: "A UDF is missing the required 'name' attribute" | The script was modified with a `<UDF>` tag that has no `name`. Use the current `src/StackScript`. |

The [2020 Plone Conference guide](archive/) describes the original Plone 5.2 version and is kept for reference.
