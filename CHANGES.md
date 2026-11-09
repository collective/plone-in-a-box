2.8 (2026-11-09)
----------------

- Hetzner Cloud: paste the launcher (src/user-data.sh) into the Cloud config
  box when creating a server, or use Terraform from src/hetzner/ (server, SSH
  key and a Hetzner Firewall allowing 22, 80 and 443). Setup guide "Option D:
  Hetzner", and Hetzner in the README and the provider comparison.
- scripts/test-deploy.sh: hetzner, in a separate piab-test project. Tested on a
  CPX02 (x86, 1 GB) and a CAX11 (Arm, 4 GB); Terraform tested too.
  [tkimnguyen]


2.7 (2026-11-08)
----------------

- New servers run Ubuntu 26.04 LTS (supported until 2031-05): the AWS Launch
  Stack template and Terraform configuration, the DigitalOcean Terraform
  configuration and the docs now use it. The provisioning script didn't need
  changes; tested on Linode, DigitalOcean and AWS. Ubuntu 24.04 still works,
  and existing 24.04 servers keep running as they are.
- scripts/test-deploy.sh: PIAB_TEST_UBUNTU chooses the Ubuntu release (26.04
  by default, or 24.04).
  [tkimnguyen]


2.6.1 (2026-11-08)
------------------

- Fix: AWS deploys with Terraform failed since 2.2, because the provisioning
  script grew past EC2's 16 KB user data limit. The user data is now
  gzip-compressed. (The console launcher and Launch Stack button weren't affected.)
  [tkimnguyen]


2.6 (2026-11-08)
----------------

- AWS without the command line, the easy way: a Launch Stack button
  (CloudFormation template src/aws/cloudformation.yaml) opens a form for the
  admin password, server size, domain and SSH options. The stack creates the
  server, a security group and a fixed address (Elastic IP), and the server
  downloads the provisioning script from the release, like the launcher does.
  Deleting the stack removes everything. CI runs cfn-lint on the template.
- README: lead with the no-command-line route for each provider (Linode's
  StackScript form, the launcher pasted on DigitalOcean and AWS) and the
  browser consoles, and move Terraform and server administration into a
  section for developers and system administrators.
- README and setup guide: which provider to choose. Linode has the simplest
  setup and among the lowest prices; DigitalOcean costs about the same; AWS
  takes the most steps and costs more for a small site.
- Setup guide: for AWS and DigitalOcean, "Console deployment (easiest)" now
  comes before "Terraform deployment (automated, more technical)".
  [tkimnguyen]


2.5 (2026-11-08)
----------------

- Install all Ubuntu updates during setup (`apt-get full-upgrade`, so new kernels
  too). If they need a restart, the server restarts once early in setup, before
  Plone is installed, and setup continues by itself; the progress page stays up.
- Add the 2 GB swap file whenever memory plus existing swap is under about 3 GB,
  not only when there is no swap. Linode servers come with a 512 MB swap disk, so
  1 GB Linodes didn't get the swap file before. A 1 GB Linode (Nanode) is now
  enough for a small site, like a 1 GB DigitalOcean Droplet.
- Setup guide: keeping Ubuntu up to date (`apt full-upgrade`, restart, and don't
  use `do-release-upgrade`).
- AWS without Terraform or a command line: paste `src/user-data.sh` into the EC2
  console's "User data" box when launching an Ubuntu 24.04 instance, like the
  DigitalOcean startup script. Setup guide steps cover the AMI, instance type,
  HTTP/HTTPS in the security group, a 20 GiB disk, EC2 Instance Connect for the
  password, and an Elastic IP before using a domain.
- The launcher script moved from `src/digitalocean/user-data.sh` to
  `src/user-data.sh`, since it now serves both DigitalOcean and AWS.
  [tkimnguyen]


2.4 (2026-11-05)
----------------

- Default to Plone 6.2 with Volto 19 (was Plone 6.1 with Volto 18). Volto 19 has
  had final releases since 2026-05; the README wrongly said it hadn't. Both
  versions are still configurable, and `6.1` / `18` still work. Existing servers
  keep their versions; to move one to 6.2, follow "To move to a newer Plone or
  Volto release" in the setup guide and Plone's 6.2 upgrade notes.
  [tkimnguyen]


2.3 (2026-11-05)
----------------

- DigitalOcean without Terraform or a command line: paste the short
  src/digitalocean/user-data.sh into the Droplet's "Startup scripts" box and
  fill in its settings (admin password, domain, time zone, versions), like the
  Linode StackScript form. It downloads the provisioning script from a pinned
  release and runs it, so there is no snapshot to build or maintain. The admin
  password is the first setting, and the docs explain reading or resetting it from
  the browser-based Droplet Console if it was left empty.
- DigitalOcean: a 1 GB Droplet is enough for a small site (tested: about 730 MB
  RAM and 100 MB swap in use).
  [tkimnguyen]


2.2 (2026-11-01)
----------------

- Let the user choose the Plone admin password at deploy time: a new "Plone admin
  password" field on the Linode StackScript, and an `admin_password` variable for
  the AWS and DigitalOcean Terraform configurations. With it set, no SSH is needed
  to start using the site. Shorter than 12 characters or empty: a password is
  generated as before. A chosen password is not written to the credentials file.
- Show the site address on the server console login screen once provisioning is done.
- Setup progress page: within a minute or two of booting, the server's address shows
  the provisioning steps and refreshes itself until the Plone site is ready; if a step
  fails, it says which one.
- Log all provisioning output to /var/log/plone-in-a-box.log on every provider.
- New `sudo plone-reset-admin-password` command on the server.
- The admin password is passed to containers through the environment rather than
  the command line.
  [tkimnguyen]


2.1 (2026-11-01)
----------------

- Add DigitalOcean support: Terraform configuration in src/digitalocean/ (Droplet,
  SSH key, Cloud Firewall) running the same provisioning script as user data;
  setup guide section, including the no-Terraform user-data route.
- Move the AWS configuration from src/aws.tf to src/aws/main.tf, so each provider
  is its own Terraform project. If you have Terraform state from src/, move
  terraform.tfstate (and .terraform.lock.hcl) into src/aws/ before running again.
- CI validates both Terraform configurations.
  [tkimnguyen]


2.0 (2026-11-01)
----------------

- Security: Plone, Volto and PostgreSQL now listen on localhost only; previously
  PostgreSQL (plone/plone) and Zope (admin/admin) were reachable from the internet.
- Security: generate random admin and database passwords, written to
  /root/plone-credentials.txt; remove the `plone` Linux user with password `plone`.
- Security: enable the ufw firewall (SSH, HTTP, HTTPS only) and optional
  Let's Encrypt HTTPS via a domain name setting.
- Disable the image's admin:admin `inituser` file, which reset the admin
  password every time the backend container was recreated.
- Update to Plone 6.1 / Volto 18 / PostgreSQL 17 (pinned, configurable) and
  Ubuntu 24.04; install Docker Compose v2 from Docker's repository; support arm64.
- Replace the fixed `sleep 120` with health checks; create the site with the
  image's `create-site` command; fail fast on errors (`set -euo pipefail`).
- nginx: allow uploads up to 100 MB; make the virtual host rules scheme-aware for HTTPS.
- Add swap on servers with less than 3 GB of RAM.
- aws.tf: fix the invalid self-reference and missing key pair dependency; look up
  the current Ubuntu AMI; add a security group; provision via EC2 user data instead of
  remote-exec; make the SSH key, region, size, domain and versions variables;
  AWS provider 5.x.
- Remove src/provision_aws.sh (superseded by aws.tf).
- Add CI: ShellCheck and `terraform validate`.
- New step-by-step guide, docs/setup-guide.md; the 2020 guide moved to docs/archive/.
- Tested on Linode (StackScript) and AWS (Terraform), Ubuntu 24.04.
  [tkimnguyen]


1.1 (2021-11-13)
----------------

- updates for Plone 6 alpha 1, working on AWS and Linode)
  [tkimnguyen]


1.0 (2020-12-10)
----------------

- first release, as presented at 2020.ploneconf.org, working on AWS and Linode (DigitalOcean not yet implemented)
  [tkimnguyen]
