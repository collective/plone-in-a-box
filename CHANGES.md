2.27 (2026-11-28)
-----------------

Look after your site without the command line:

* **A control panel (preview):** a page on your phone or computer that
  shows how your site is doing, in plain words, with buttons to back up
  now, run the restore test, and give the demo login a new password after
  a workshop. Tick Control panel when you create the server.

* **Ask your AI assistant (preview):** Claude and other assistants can tell
  you whether your site is healthy, when it was last backed up, or why an
  update failed, straight from your server.

* **A start page** at https://collective.github.io/plone-in-a-box/ shows
  the easiest way to get started, and what can wait until your site is
  running.

* **Safer pages:** up-to-date security headers on every page.

- **A start page** at https://collective.github.io/plone-in-a-box/: the
  easiest way first (pick a provider, choose the admin password, click
  Create), with a button for each provider; what can wait until the site is
  running (domain name, email, offsite backups, notifications, logs, graphs,
  add-ons, a theme); and which fields to fill in for what the site is for
  (trying Plone, an organization's site, an intranet, a demo, a workshop, an
  add-on). `scripts/catalog.py pages` writes it with the Try It pages, so it
  always names the current release. The README starts with the same three
  steps, and the slides have a "Choose your path" slide.
- **`plone-status`**: how the server and site are doing, in one place: whether
  the site answers, its parts, the versions, disk and memory, the last backup
  and restore test, the last update, and which features are on. Read only.
  `--json` gives the same for programs, the groundwork for the box control
  panel and MCP. Older servers get it from `src/add-updates.sh`.
- **The Plone in a Box control panel (preview)**: `sudo plone-panel on`
  shows how your site is doing in your browser, in plain words, on your
  phone or computer: the same as `plone-status`, with buttons for a few
  low-risk things (back up now, run the restore test, send a test
  notification or email, stop sending logs or graphs), and times in your own
  time zone. Separate from the Plone site, so it still works when Plone
  doesn't: at `box.<your domain>` (after a DNS record for it), or on port
  8443 for a site without a domain name. Its own login, `box`, which isn't
  an account on the server; repeated failed logins are blocked (fail2ban).
  Our own small program, with nothing to install: nginx asks for the login,
  and the program, which can't change the server itself, can ask root only
  for the status and the buttons. Off until you turn it on; `plone-panel
  off` turns it off again. `scripts/test-deploy.sh --panel` tests it. The
  Launch Stack template and the Terraform plans' firewalls allow port 8443
  (nothing answers there until the panel is on).
- **Using an AI assistant (MCP, preview)**: `plone-mcp` lets Claude and
  other assistants answer "is my site healthy?", "when was the last
  backup?" or "why did the update fail?" from the server itself, through
  your SSH connection (`ssh root@<server> plone-mcp`), so nothing new is
  open to the internet. Read-only tools (status, backups, updates, logs
  with secrets hidden, features, security notices, running jobs), and
  three of the control panel's buttons (back up now, the restore test, a
  test notification), each at most once a minute. Older servers get it
  from `src/add-updates.sh`.
- **A Control panel field in the launch form** (Linode, the Launch Stack
  template, the Terraform plans and the launcher): turns the panel on at
  `https://<your site>:8443` when the server is created, with its login in
  the credentials file next to the admin password, so no SSH is needed.
  Off by default while it's a preview.
- **New demo password**, a button in the control panel (and `sudo plone-panel
  do demo-password`): gives the demo login a new password after a workshop
  or demo, shows it once, and updates the credentials file.
- The OpenTelemetry Collector (graphs) is 0.166.0.
- Behind Cloudflare (`plone-cloudflare on`), the control panel on port 8443
  is reachable only through Cloudflare too, like the site, so the server's
  own address stays hidden.
- **Security headers**, reviewed against OWASP's current recommendations:
  `Referrer-Policy` (what browsers do by default, now said), a
  `Content-Security-Policy` with only the parts that can't break a Plone site
  (`frame-ancestors 'self'; base-uri 'self'; object-src 'none'`; Volto's
  pages have inline scripts, so a full one can't), a `Permissions-Policy`
  turning off camera, microphone, payment and USB, no `X-Powered-By`
  naming Zope and Python, and one `X-Frame-Options` instead of two.
  "Adding a domain later" in the setup guide now adds
  `Strict-Transport-Security`, as setup does for a domain. Older servers get
  the headers from `src/add-updates.sh`.
- **Starter content** now says what it is in every form and in the guide:
  Plone's welcome page (or a Plone distribution's own sample content), not
  "sample pages", which a standard Plone 6.2 site doesn't have.

2.26 (2026-11-27)
-----------------

See how your site is doing over time:

* **Graphs of your server and site:** optional `plone-otel` sends your
  site's health (memory, disk, response times, errors) to an OpenTelemetry
  service, including Grafana Cloud's free plan, with a ready-made
  dashboard. Thanks to Jean Jordaan (@jean), a longtime Plonista with a gift
  for finding great software tools and methods, for the idea!

* **Logs and graphs from the start:** turn them on in the launch form, and
  a new server sends them as soon as it's ready.

* **Try Plone Aurora:** the demo login can now add pages and images too.

- **Graphs of your server and site**: `sudo plone-otel on ENDPOINT` sends
  the server's numbers (CPU, memory, disks, network), each of Plone's,
  Volto's, PostgreSQL's and nginx's memory and CPU, PostgreSQL's and nginx's
  own, and Plone's (request times, errors, database size and cache, content
  counts, from plone.observability) to an OpenTelemetry service once a
  minute, such as Grafana Cloud's free plan. An OpenTelemetry Collector
  container gathers them (about 50 MB of memory); it reads the server's
  disks and processes read-only, only sends, and checks the token before
  anything changes. PostgreSQL's numbers come from a login that can read
  statistics, not content. With the official backend image, Plone's response
  times and errors too: plone.observability's filters are added to the
  image's `zope.ini` at each start, and Docker's health check moves to its
  health server, which also checks the database. A ready-made Grafana
  dashboard is in `docs/grafana/`. `status` shows what was sent and what
  failed; `off` removes it all. Older servers get it from
  `src/add-updates.sh`. ("Graphs of your server and site" in the setup
  guide.) Thanks to Jean Jordaan (@jean), a longtime Plonista with a gift
  for finding great software tools and methods, for the idea of adding
  OpenTelemetry to Plone in a Box.
- **Logs and graphs from the start**: new optional launch fields send the
  server's logs to a syslog service (`plone-syslog`) and its numbers to an
  OpenTelemetry service (`plone-otel`) from the moment setup finishes: Log
  server, Log token and Log each web request; OpenTelemetry endpoint, user
  and token. In the Linode form, the Launch Stack form, Terraform
  (`log_server`, `log_token`, `log_requests`, `metrics_endpoint`,
  `metrics_user`, `metrics_token`) and the launcher. The tokens are never
  logged, and the credentials file says whether each one worked.
- `plone-syslog` and `plone-otel` share one helper that writes
  `docker-compose.override.yml`, so turning one on or off keeps the other.
- The Plone Aurora Try It page gives the demo login Contributor as well as
  Editor, so the people you let try it can add pages and upload images, such
  as in an image block, as the page suggests. Editor alone can only change
  existing pages. On a server already running, give `demo` Contributor in
  Site Setup → Users.

2.25 (2026-11-26)
-----------------

Know your backups work, and stay in the loop:

* **Monthly restore test:** your server checks that its newest backup (on
  the server or offsite) can really be restored, without affecting your
  site, and tells you if it can't.

* **Server warnings reach you:** the server's own messages, such as a
  failed security update, now arrive through your site's email settings.

* **View server logs centrally:** optional `plone-syslog` sends your logs to
  a log service, including Better Stack's free plan, or your own log server.

* **Secured by Cloudflare:** optional `plone-cloudflare` lets only
  Cloudflare reach your site, to help block bots and DDoS attacks.

* **Free DigitalOcean alerts** for disk, memory and CPU spikes on Droplets
  made with the Terraform plan.

* **Safer builds:** the project's GitHub workflows are protected against a
  hijacked GitHub Action.

- **Backup checks**: once a month, `plone-backup-check.timer` restores the
  newest backup into a separate test database, has Plone open the site in
  it and read its newest pages and a file or image, then deletes the test
  database; the site isn't touched. With copies off the server, it tests the
  newest copy there, downloaded and decrypted, and says if the copies have
  stopped. A failure goes to the notification URL and by email, and shows in
  the login message. `sudo plone-backup-check` runs it now. Older servers
  get it from `src/add-updates.sh`. ("Checking the backups" in the setup
  guide.)
- **Behind Cloudflare**: `sudo plone-cloudflare on`, for a site whose
  domain is proxied by Cloudflare, lets only Cloudflare's addresses reach
  ports 80 and 443, so nobody can go around Cloudflare to the server, and
  has nginx take each visitor's own address from Cloudflare's header. It
  checks first that the domain points at Cloudflare. `plone-cloudflare.timer`
  updates Cloudflare's address list once a month; `sudo plone-cloudflare
  off` opens the ports again. ("Behind Cloudflare" in the setup guide.)
- **The server's own mail**: with the site's mail settings in place, mail
  the server sends to root (Ubuntu's automatic security updates when one
  fails, say) goes to the address for reports, through the same email
  service, from the site's From address. `plone-server-mail` configures
  msmtp from **Site Setup → Mail**; setup runs it, and the weekly update
  runs it again so changes there reach the server. `sudo plone-server-mail
  test` sends a test email. Older servers get it from `src/add-updates.sh`.
  ("The server's own mail" in the setup guide.)
- **Logs to a syslog server**: `sudo plone-syslog on HOST:PORT` sends the
  server's logs to a syslog server or service as well (Better Stack,
  Papertrail, your own rsyslog): Plone, Volto and PostgreSQL, nginx's
  requests and errors, the Plone in a Box tools' logs and the system's own.
  TLS by default (`--ca` for a private certificate authority), and up to
  100 MB wait on the server while the log server is away. The containers
  log through journald for this; `docker compose logs` still works.
  `--sd` adds the token some services want in each message (Papertrail,
  Better Stack), and `--no-access-log` leaves out the line per web request,
  most of the volume. The setup guide compares the services tried with it
  (Better Stack's free plan, Papertrail, a log server of your own), with
  what each costs and keeps, and says how to tell whether another service
  works. ("Sending the logs elsewhere" in the setup guide.)
- **DigitalOcean alerts by default (Terraform)**: a Droplet made with
  `src/digitalocean` now gets DigitalOcean's free resource alerts: an email
  when its disk is over 85% full, its memory over 90% for 10 minutes, or its
  CPU over 90% for 30 minutes, to the account's email (`alert_emails` for
  others, `alerts = false` for none). `uptime_check = true` adds an outside
  check of the site that emails when it's down or its certificate is about
  to expire; it's off by default because DigitalOcean charges $1 a month
  for each check after the first. Custom-scope tokens need monitoring,
  uptime and account read too.
- **GitHub Actions pinned to commit hashes**: the workflows named each
  action by a tag like `v7`, which whoever controls the action can move to
  other code at any time, as happened to `tj-actions/changed-files` in
  March 2025. Those workflows push the frontend and backend images that
  servers install every week, and upload the Launch Stack template with AWS
  credentials, so a hijacked action could have shipped a tampered image or
  template. Each action is now named by its commit (with its version in a
  comment), which can't change, and Dependabot proposes updates weekly as
  pull requests to review.

2.24 (2026-11-26)
-----------------

Your server now restarts by itself at night when Ubuntu's security updates
need it, such as a new Linux kernel, after any backup or update that's
running. It tells you when its disk is getting full, before backups stop,
and when one of its tools is cut off by a time limit, a lack of memory or a
crash; backup problems now come by email too. SSH is safer: when the server
has an SSH key, password logins are turned off, root's included, and
fail2ban blocks addresses that keep failing to log in. On AWS, Terraform can
now turn on daily snapshots of the server's disk, and the blocklist checks
can ask Spamhaus from any cloud provider with a free key. The setup guide
explains how to be told when the site is down, and which outgoing ports to
allow if a firewall in front of the server limits them.

- **Nightly restarts**: Ubuntu installs security updates every day but
  never restarts, so a new kernel waited for someone to run `sudo reboot`.
  `plone-reboot.timer` runs `plone-reboot` at 03:30 server time; it does
  nothing unless updates are waiting for a restart, and waits for any backup
  or update that's running. Logged in `/var/log/plone-reboot.log`; `sudo
  plone-reboot` restarts now if needed. Off with `sudo systemctl disable
  --now plone-reboot.timer`; the weekly report then says when updates have
  waited more than two days. ("Updates" in the setup guide.)
- **Disk warnings**: the nightly backup sends a notice once the disk is over
  85% full, and again at every 5 points more, and the weekly report says so
  until there's room again.
- **Backup problems by email**: they went only to the notification URL;
  now they're emailed too, with the site's mail settings.
- **When a tool stops**: if a backup, update, security-notice check, HTTPS
  renewal or nightly restart is stopped before finishing (a time limit,
  running out of memory, a crash), a notice says so, with its last log
  lines. The problems the tools find themselves are reported as before, not
  twice.
- These four come to older servers too, with the same `add-updates.sh`
  command ("Servers set up before 2.12" in the setup guide).
- **SSH keys only**: when root or the default user (`ubuntu` on AWS) has an
  SSH key, setup turns password logins off, root's included
  (`/etc/ssh/sshd_config.d/00-plone-in-a-box.conf`, read before the
  provider's own settings). A server created with only a password keeps
  password logins, so nobody is locked out, and the credentials file says
  how to turn them off. Provider browser consoles keep working. New servers
  only. ("SSH" in the setup guide.)
- **fail2ban**: an address that fails to log in over SSH 5 times in 10
  minutes is blocked for an hour, longer each time it comes back.
- **Setup guide**: "Knowing when the site is down" explains a DigitalOcean
  Uptime check (it works for a site on any provider) with a downtime alert
  and a certificate-expiry alert, AWS's Route 53 health check, and the
  resource alerts each provider has. The new "Outgoing connections" lists
  the ports the box needs if a firewall in front of it limits outbound
  traffic (time sync and email were silently blocked on a real server), and
  "Sending email" says DigitalOcean's support can open port 587.
- **Dependabot** keeps the GitHub Actions in the workflows up to date.
- **Catalog checks for ready-made images**: CI checks that each ready-made
  image in `addons.yml` can be pulled without logging in, is built for
  `linux/amd64` (and `linux/arm64` with `arm: yes`), and exposes the ports
  the official images do; it suggests `arm: yes` when every image has Arm
  builds. (`python3 scripts/catalog.py images`.)
- **Old backend image builds are deleted** like the frontend ones: each
  backend image keeps its newest 26 weekly builds. Builds replaced later the
  same day, which keep only their commit tag, now count too.
  (`scripts/cleanup-images.py`, which replaces
  `scripts/cleanup-frontend-images.py`.)
- **Server backups on AWS**: Terraform's new `backups` setting turns on
  daily snapshots of the server's disk through AWS Data Lifecycle Manager,
  the newest 7 kept, as `backups` does on DigitalOcean and Hetzner. For
  Launch Stack servers, the setup guide gives the steps to make the same
  policy in the AWS console. ("Backups" in the setup guide.)
- **Spamhaus from any cloud provider**: the new optional **Spamhaus DQS
  key** setting, in every route (Linode form, Launch Stack `SpamhausKey`,
  Terraform `spamhaus_key`, the launcher's `SPAMHAUS_KEY`), makes the
  blocklist checks ask Spamhaus through its free Data Query Service, which
  answers from any network: without it, Spamhaus refuses Hetzner's and
  DigitalOcean's DNS resolvers, and those checks were skipped. Only root can
  read the key on the server; the credentials file and the weekly report say
  if it doesn't work. ("Blocklists" in the setup guide.)


2.23 (2026-11-25)
-----------------

Your site can now use private images: give the login for their registry
when you create the server, and setup and the weekly updates use it. Setup
also checks your site's domain, your email's domain and the server's IP
address against the public blocklists mail services use, and the weekly
report tells you if a domain gets listed, so email that lands in spam has a
reason you can act on. Plone Aurora now runs on Arm servers too.

- **Private images**: the new **Registry username** and **Registry token**
  settings log in to the registry of a private frontend or backend image,
  in every route (Linode form, Launch Stack, Terraform `registry_user` and
  `registry_token`, the launcher's `REGISTRY_USER` and `REGISTRY_TOKEN`).
  Docker keeps the login on the server, so the weekly updates pull new builds
  too. The token isn't logged, and the credentials file says whether the
  login worked. ("Private images" in the setup guide.)
- **Blocklist checks**: setup looks up the site's domain and the From
  address's domain in the Spamhaus domain list and SURBL, and the server's IP
  address in Spamhaus ZEN and SpamCop, and the credentials file says if one is
  listed, with the page that explains how to have it removed. The weekly
  update looks up the domains again and says so in its report. Lists that
  don't answer through the provider's DNS resolver are skipped. ("Sending
  email", "Blocklists" in the setup guide.)
- **Plone Aurora on Arm servers**: the Aurora backend image is built for Arm
  (`linux/arm64`) as well as x86, so its Try It page works on Hetzner's Arm
  servers too, and no longer says to choose x86. The catalog's new `arm` key
  says when a ready-made entry's images run on Arm.

2.22 (2026-11-24)
-----------------

Try Plone Aurora, the new React frontend for Plone, on a server of your own:
its Try It page sets up a site with Aurora in about ten minutes. Plone
distributions, such as kitconcept's intranet, set up again (2.21 broke
them), and a backend image that can't create the site no longer stops
setup: the site starts with the official Plone backend instead. Add-on and
distribution makers who publish their own images can now have a Try It page
too.

- **Try It for ready-made images**: the catalog (`addons.yml`) takes
  `frontend_image` and `backend_image`, for add-ons and Plone distributions
  whose makers publish their own images: nothing is built for them, and their
  Try It page fills in both images. "Try It" buttons explains them.
- **Fixed: Plone distributions failed to set up.** Since 2.21, setup sent
  `SITE_SETUP_CONTENT`, which kitconcept's images can't read: creating the
  site stopped with an error, for the intranet and anything built on
  kitconcept.core. Setup now gives a distribution's image a copy of its own
  answers file (`/app/scripts/default.json`) with the starter content
  setting and no Solr, so Starter content `no` works for them too.
- **A backend image that can't create the site** no longer stops setup: on a
  new server, setup empties the database and creates the site with the
  official Plone backend instead, and the credentials file says why. As
  before, a backend image that can't be pulled or doesn't start is replaced
  the same way.
- **Try Plone Aurora**, the new React frontend for Plone, still in
  development: a Try It page with the `plone/aurora` image and a new
  ready-made backend image, `ghcr.io/collective/plone-in-a-box-backend:6.2-aurora`
  (Plone 6.2 with the newer `plone.restapi` and `plone.volto` Aurora needs,
  and its `plone.volto:aurora` profile), built weekly by GitHub Actions.
  The frontend gets `PLONE_API_PATH`, so an Aurora frontend image finds the
  backend, and the update report names Aurora's version instead of Volto's.

2.21 (2026-11-24)
-----------------

Every site is now on HTTPS, also without a domain name: the server gets a
certificate for its IP address and renews it by itself, so passwords never
travel unencrypted. You can create your site in your own language (`de`,
`fr`, `pt-br`, …), with or without the sample pages, and run a whole Plone
distribution, such as kitconcept's intranet, with the new Backend image
setting. Backups now include the server's settings, and the weekly report
says if they've stopped.

- **HTTPS without a domain name**: a site without one now gets a Let's
  Encrypt certificate for the server's IP address and is at `https://<ip>`,
  with HTTP redirecting to it. These certificates last about six days; the
  server renews them twice a day (`plone-https-ip.timer`) and sends a notice
  if renewing keeps failing. `sudo plone-https-ip off` goes back to HTTP.
  Certbot runs from its official image (Ubuntu 26.04's is too old for IP
  addresses). nginx's site settings moved into a snippet shared by HTTP and
  HTTPS. "Adding a domain later" in the setup guide has the steps for a server
  with an IP address certificate.
- **Backend image**, a new optional setting on every route (the Linode form,
  Launch Stack, Terraform's `backend_image`, the launcher): it replaces the
  official Plone backend, for example with a Plone distribution such as
  kitconcept's intranet (with its frontend image), or your own project made
  with cookieplone. Setup checks that the image runs Plone with the server's
  settings, and otherwise starts with the official backend and says why. Sites
  are created with English, the server's time zone and no Solr, whatever the
  image. The weekly update covers the image too. `test-deploy.sh` has
  `--backend-image` and `--expect-backend-fallback`, and
  `linode-addon-stackscript.sh` has `--backend-image`.
- **Site language** and **Starter content**, new settings on every route: the
  site is created in the language you choose (a code such as `de` or `pt-br`;
  English by default), and with or without the sample pages a new site or a
  Plone distribution comes with.
- A frontend image that's pulled but doesn't start (built for another Volto
  version, say) no longer stops setup: the site starts with the standard
  Volto image instead, and the credentials file says why.
- The weekly update report says so when the newest database backup is more
  than two days old (backups that stopped without failing).
- Each nightly backup now also saves the server's own settings
  (`plone-<date>.config.tar.gz`: `.env`, the compose file and the nginx site),
  and copies them off the server with the database backup when that's set up.

2.20 (2026-11-23)
-----------------

Your site's nightly backups can now also go somewhere other than the server
itself: run `sudo plone-offsite setup` once, and each night's backup is
encrypted and copied to S3-compatible storage such as Cloudflare R2 (free for
small sites), AWS S3, Backblaze B2, DigitalOcean Spaces or Hetzner. If the
server is ever lost, set up a new one and restore your site from a copy. See
"Copies off the server" in the setup guide.

- `sudo plone-offsite setup` sends a copy of each night's backup to
  S3-compatible storage (Cloudflare R2, AWS S3, Backblaze B2, DigitalOcean
  Spaces, Hetzner Object Storage and others), encrypted with a passphrase on
  the server first, and keeps the newest 14. `plone-offsite list` and `fetch`
  get one back, also on a new server, for `plone-restore`.

2.19 (2026-11-23)
-----------------

When a Plone security fix comes out, servers with automatic updates now
install it the same day instead of waiting for Sunday, and tell you they did.
The setup guide has a table of what the server does and what you do for each
kind of Plone announcement. And `sudo plone-restore` puts a backup back, or
moves your site to a new server. Servers set up before 2.19 get both by
running `add-updates.sh` again (see the setup guide).

- When a Plone security fix is released and automatic updates are on, the
  server installs it the same day instead of on Sunday, and if its images
  aren't out yet, tries again every day for a week. The security notice says
  what happened: installed, not out yet, or failed and undone. The setup
  guide's new "Security fixes and new Plone releases" section has a table of
  what the server does and what you do for each kind of announcement, and
  upgrading to a new Plone version has its own section.
- `sudo plone-restore` puts a database backup back: the whole site as it was
  when the backup was taken. It saves a backup of the site as it is first, and
  puts that back if the restore fails. It also moves a site to a new server:
  copy a backup there and restore it. See "Backups" in the setup guide.

2.18 (2026-11-23)
-----------------

Servers now tell you about Plone security fixes: once a day they check the
Plone forum's Security category and pass each new announcement on to your
notification URL, your email and the login message, so you hear about a fix,
often a week ahead. If you set up your server with Terraform, it's now
protected from being deleted or rebuilt by mistake, including after pulling
a newer Plone in a Box, and on DigitalOcean and Hetzner Terraform picks a
region that offers the server size you chose. Servers from the AWS Launch
Stack button have termination protection too.

- Security notices: every day the server checks the Security category of the
  Plone forum, and sends each new post (security fixes and their
  pre-announcements) to the notification URL, by email and to the login
  message. `sudo plone-security-notices` checks now; servers set up before
  2.18 get it by running `add-updates.sh` again.
- AWS Terraform: the server downloads the setup script of the release in the
  new `release` variable (the current release by default), as the Launch
  Stack template does, instead of carrying it in its user data. The script
  had grown close to EC2's 16 KB user data limit.
- Hetzner and DigitalOcean Terraform: likewise, the server downloads the
  setup script of the release in the new `release` variable, so all three
  Terraform routes work the same way. On Hetzner, the compressed script had
  reached 29 of the 32 KB of user data allowed.
- DigitalOcean and Hetzner Terraform choose the region or location
  automatically: the first one in the new `preferred_regions` or
  `preferred_locations` list that offers the size, and print it. A region or
  location you set that doesn't offer the size now stops Terraform before
  anything is created, with a list of the ones that do, instead of failing
  halfway with "Size is not available in this region" (as nyc3, the old
  DigitalOcean default, did in November 2026). A server stays where it was
  created when availability changes later.
- Terraform (AWS, DigitalOcean and Hetzner) no longer replaces a server, and
  so deletes its site, when its user data, SSH key or Ubuntu image would
  change: for example after pulling a newer Plone in a Box, whose new
  `release` changes the user data, or when Canonical publishes a newer Ubuntu
  image on AWS. Those settings are used only when the server is created.
- Terraform never deletes a server: `terraform destroy` and changes that need
  a new server stop with an error (`prevent_destroy`), and on AWS and Hetzner
  the provider refuses too, also in its web console (the new
  `deletion_protection` variable, on by default). "Removing the box" in the
  setup guide shows how to remove one on purpose.
- AWS Launch Stack: the server has termination protection, so deleting the
  stack by mistake can't delete it, and a stack update that needs a new
  server keeps the old one; the Elastic IP is kept when the stack is deleted.
  "Removing the box" in the setup guide shows how to remove it on purpose.

2.17 (2026-11-22)
-----------------

New servers now send standard security headers that stop other sites from
framing your site, hide nginx's version number, and compress pages' styles
and scripts so they load faster. You can also try Volto Light Theme on a
server of your own from its new Try It page, with a demo login that can edit
the theme's settings.

- nginx: security headers on every response (X-Frame-Options SAMEORIGIN,
  X-Content-Type-Options nosniff, and Strict-Transport-Security once HTTPS
  is set up), no version number in responses, and compressed CSS,
  JavaScript, JSON and SVG, on new servers (in the site's server block,
  since Ubuntu's nginx.conf sets some of these itself). scripts/test-deploy.sh checks
  them.
- Try It page for Volto Light Theme
  (https://collective.github.io/plone-in-a-box/try/vlt/), with a demo login
  that has the Editor role, so it can edit pages and the theme's settings.
- scripts/test-deploy.sh: --keep-on-failure keeps the test server when a
  check fails, to look at it or retry the check.
- Docs and slides: plainer wording in a few places.

2.16 (2026-11-22)
-----------------

Your site now backs up its database every night, and once a week clears out
old history that would otherwise make the database keep growing. A server
set up earlier gets this with the same one-line command as automatic
updates. Server logs no longer grow without limit on new servers.

- Nightly database backups and a weekly pack: plone-backup, run every night
  by plone-backup.timer, saves a database backup in /var/backups/plone (the
  three newest are kept, with plone-update's), and once a week packs the
  database, removing history older than 7 days, which otherwise makes it
  grow forever. A failure is reported at the notification URL. Older
  servers get it from src/add-updates.sh.
- Container logs are limited to 30 MB each (Docker keeps them all by
  default), on new servers.
- scripts/test-deploy.sh aws --cloudformation: creates the server as the
  Launch Stack button does, from the branch's template, and deletes the
  stack afterwards; list and cleanup include test stacks.
- Docs: an invitation to the #plone-in-a-box channel on the Plone Discord
  (https://discord.gg/jRrsnYkNvS) in the README, the setup guide's Troubleshooting, the Try It
  pages and the release notes.
- Slides (docs/slides): updated to this release: updates, email, the demo
  login, Try It pages and what's next.

2.15 (2026-11-22)
-----------------

Your site can now send email (password resets, forms and the weekly update
reports) through an email relay service such as SMTP2GO or Brevo: fill in
its settings when you create the server, and setup sends you a test email.
The setup guide compares the services. And add-on authors can now offer a
"Try It" page for their add-on with a single pull request.

- Releasing: .github/workflows/publish-template.yml uploads the Launch Stack
  template to S3 when a release is published (signing in to AWS with
  GitHub's OpenID Connect, no stored keys), and
  scripts/update-public-stackscripts.sh updates the public Linode
  StackScripts (931893, 2318969, 692002) from a release's tag.
- Add-on catalog and Try It pages: addons.yml lists the ready-made frontend
  images (the image workflow builds from it) and the add-ons with a Try It
  page. For each, scripts/catalog.py writes docs/try/<id>/, published at
  https://collective.github.io/plone-in-a-box/try/<id>/: the AWS Launch
  Stack link, the Linode steps, and the DigitalOcean and Hetzner lines for
  the current release. An add-on author's whole job is one pull request
  with an entry and one button in their README. CI checks the entries
  (exact versions, never Manager) and that the pages are up to date.
- Old frontend image builds are deleted after each image build
  (scripts/cleanup-frontend-images.py): each image keeps its newest 26
  builds, about six months, and test images go after 7 days.
- Email: new optional settings for an email relay service (SMTP server, port,
  username, password, From address, and an address for reports) in the
  Linode form, src/user-data.sh, the Launch Stack form and the Terraform
  variables. Setup puts them into Site Setup > Mail, so password resets and
  forms send email, and sends a test email to the address for reports; the
  credentials file and the first notification say whether it went out. The
  weekly update reports are emailed there too. With email set up, the demo
  login gets Editor instead of Site Administrator, who could otherwise get
  the email service's password from Site Setup > Mail.
  scripts/test-deploy.sh --mail tests it.
- Docs: demo and admin passwords cross the network unencrypted on a site
  without a domain; choose ones not used anywhere else.
- Docs: sending email (password resets, forms, update reports) through an
  email relay service, with a comparison of SMTP2GO, Brevo, Mailgun, Amazon
  SES, Postmark and Resend, and how to set it up in Site Setup > Mail.
  [tkimnguyen]

2.14 (2026-11-22)
-----------------

- Demo login roles: the demo login can have several roles, separated by
  commas (DEMO_ROLES in src/user-data.sh, the Linode StackScript's "Roles of
  the demo login" field, the DemoRoles parameter, the demo_roles Terraform
  variable), including roles that add-ons define. Left empty, it gets the
  roles the frontend image suggests in its new org.plone-in-a-box.demo-roles
  label (the demo_roles field of an image), or Site Administrator. Roles the
  site doesn't have are skipped, and Manager is never given. DEMO_ROLE (2.13)
  still works when set to another role than Site Administrator.
- Demo login password: an optional setting (DEMO_PASSWORD, the Linode
  StackScript's "Demo login password" field, the DemoPassword parameter, the
  demo_password Terraform variable), at least 12 characters. Left empty, it
  is generated and saved in /root/plone-credentials.txt, as before; a chosen
  one isn't saved on the server.
- The Juizi Dashboard image: juizi.dashboard 1.0.0b3, whose demo login gets
  Editor and Site Activity Viewer (a role that sees the activity dashboard
  and nothing else), instead of Site Administrator.
- Releases are announced on Discord (#plone-in-a-box) when their tag
  reaches collective/plone-in-a-box (.github/workflows/release-notice.yml).
- scripts/linode-addon-stackscript.sh: --demo-roles instead of --demo-role,
  empty by default. scripts/test-deploy.sh: --demo-roles,
  --expect-demo-roles and --demo-password.

2.13 (2026-11-21)
-----------------

- Demo login: an optional setting (DEMO_USER and DEMO_ROLE in
  src/user-data.sh, the Linode StackScript's "Demo login" fields, the
  DemoUser and DemoRole parameters, the demo_user and demo_role Terraform
  variables). Setup creates a second Plone login with that role (Site
  Administrator by default) and a generated password, saved in
  /root/plone-credentials.txt, for people you let try the site.
- "Try It" buttons for add-ons (docs/try-it-buttons.md): a link that sets up
  a server with an add-on and a demo login. On AWS the Launch Stack link
  fills in the parameters; on Linode, scripts/linode-addon-stackscript.sh
  prints a StackScript for one add-on, with its settings filled in, that
  downloads the latest release.
- A ready-made frontend image with Juizi Dashboard (an activity record and
  dashboard for site administrators): ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard.
- scripts/test-deploy.sh: --demo-user and --demo-role check the demo login;
  --linode-script tests such a StackScript.
- The obsolete Linode StackScript 692002 has the demo login fields too.

2.12 (2026-11-21)
-----------------

- Automatic updates: a new setting (the Linode StackScript's "Automatic
  updates" field, AUTO_UPDATE in src/user-data.sh, the Launch Stack template's
  AutoUpdate parameter and the Terraform auto_update variable), on by default.
  Every week the server installs newer images of the same Plone, Volto and
  PostgreSQL versions (patch releases and security fixes). If there's
  anything new, it first saves a database dump in /var/backups/plone, then
  checks that the site comes back, and goes back to the previous images if it
  doesn't. The result is in the login message, and is emailed to the site's
  address when Site Setup > Mail is set up; it also says when a newer Plone
  release is out, which stays a manual upgrade. sudo plone-update runs it by
  hand. scripts/test-deploy.sh --updates tests it.
- Notification URL: an optional setting (NOTIFY_URL, the NotifyUrl
  parameter, the notify_url Terraform variable) where update reports are
  posted: ntfy (https://ntfy.sh/<topic>) for phone notifications, or a Slack,
  Discord, Google Chat, Mattermost or Microsoft Teams (workflow) webhook.
  Setup sends a first notice when the site is ready. Only root can read the URL on the server.
- Servers set up before 2.12 (2.0 or later) get automatic updates with one
  command on the server: curl ... src/add-updates.sh | sudo bash (setup guide,
  "Servers set up before 2.12"). It installs the same update tools as setup,
  taken from the release's provisioning script, optionally with a
  notification URL, and runs plone-update once. Running it again updates the
  tools.
- Fix: Terraform on Hetzner would fail, because the provisioning script grew
  past Hetzner's 32 KiB user data limit; on AWS it was close to EC2's 16 KB.
  The DigitalOcean and Hetzner configurations now send the script compressed
  and unpack it on the server, and the AWS one leaves out its comment lines
  before compressing. CI checks the sizes.
- scripts/test-deploy.sh: --notify-url URL sends the notices to a topic you
  watch. On a Mac it keeps the computer awake while it runs (caffeinate), since
  idle sleep stalled the checks and failed them. On Linode it sends only the
  settings that are set, so older releases (--ref 2.9) can be deployed.
- scripts/test-notify.sh sends sample update notices to real Teams, Slack,
  Discord, Google Chat, Mattermost or ntfy channels, with webhook URLs kept in
  the Keychain. Tested with all of them.
- Docs: knowing when the site is down, with an uptime check.
- Docs: building your own frontend image with other Volto add-ons (fork, add
  an entry to the workflow, and GitHub Actions builds and publishes it), and
  using a custom backend image on a running server, for packages that aren't
  on PyPI. Ready-made frontend images are x86 only; on Arm servers setup uses
  the standard Volto image.
  [tkimnguyen]


2.11 (2026-11-20)
-----------------

- Volto Light Theme, and other frontend images: a new optional setting (the
  Linode StackScript's "Frontend image" field, FRONTEND_IMAGE in
  src/user-data.sh, the Launch Stack template's FrontendImage parameter and
  the Terraform frontend_image variable) replaces the standard Volto image.
  With ghcr.io/collective/plone-in-a-box-frontend:19-vlt the site runs Volto
  Light Theme: setup also installs and activates its backend add-on and turns
  on its site settings (logo, colours, footer). An image that can't be pulled,
  or whose backend add-ons can't be installed, is left out, and the site uses
  the standard Volto image; the credentials file and the log say why.
- Ready-made frontend images, built by .github/workflows/frontend-images.yml
  and published from collective/plone-in-a-box. Their labels name the backend
  add-ons and site behaviors they need. Rebuilt every week.
- Fixed: when setup continued after a restart for updates, the last lines of
  its log, "Finished" among them, could be lost, although setup had
  completed.
- The credentials file and the log no longer ask you to activate add-ons that
  setup already activated for the frontend image.
- scripts/test-deploy.sh: --frontend-image IMAGE and
  --expect-frontend-fallback. SSH keepalives, so a hung connection can't
  stall a test, and the setup log is kept when setup times out.
- scripts/aws-test-cloudformation-policy.json: a managed policy that lets the
  AWS test user run Launch Stack tests (stacks named piab-test-*).
  [tkimnguyen]


2.10 (2026-11-20)
-----------------

- Backend add-ons without a custom build: an optional setting (the Linode
  StackScript's "Backend add-ons" field, ADDONS in src/user-data.sh, the
  Launch Stack template's Addons parameter and the Terraform addons variable)
  lists Python packages, such as collective.easyform, for the plone-backend
  image to install. Activate them afterwards in Site Setup > Add-ons. Setup
  tries the install first and continues without the add-ons if it fails, and
  says so in the credentials file and the log. Frontend (Volto) add-ons still
  need a custom image.
- scripts/test-deploy.sh: --addons "PKG ..." checks the add-ons can be
  activated and stay active after restarts; --expect-addons-skipped checks
  that bad names are left out. PIAB_LINODE_TYPE and PIAB_DO_SIZE pick the
  server size. Test SSH keys on Hetzner and AWS are named after their
  fingerprint, so several computers can run the tests (update the AWS test
  user's inline policy from scripts/aws-test-policy.json).
  [tkimnguyen]


2.9 (2026-11-09)
----------------

- DigitalOcean and Hetzner: the README and setup guide now give a three-line
  launcher to paste, with a CHANGE-ME placeholder for the admin password (a
  forgotten placeholder is too short, so a password is generated instead). The
  full launcher, src/user-data.sh, is still there for more settings.
- CI checks that the launchers, the Launch Stack template and the docs all
  download the same release.
- scripts/test-deploy.sh: PIAB_TEST_LAUNCHER=short tests the three-line launcher.
  [tkimnguyen]


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
