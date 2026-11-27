# TODO

## Automated test deploys

`scripts/test-deploy.sh` runs the Linode, DigitalOcean, AWS and Hetzner tests (see RELEASING.md). Still open:

- [ ] Renew the Linode token when it expires (1 month; the DigitalOcean token made on 2026-11-22 doesn't expire),
  and rotate the AWS access key.

## Per-add-on StackScripts after 2.24

- [ ] 2.24 added a form field, **Spamhaus key** (`SPAMHAUS_KEY`), so per-add-on "Try It" StackScripts made with
  `scripts/linode-addon-stackscript.sh` should be printed again and pasted over the old ones in Cloud Manager
  (RELEASING.md, "Per-add-on StackScripts"). The Juizi Dashboard one (2318969) is done: `update-public-stackscripts.sh`
  updated it. Check for any others, in our accounts or made by add-on authors, and tell those authors. Until then
  they keep working without the field (they download the latest release, and the field is optional).

## OpenTelemetry, and launch fields for logs (next release after 2.25)

- [x] `plone-otel` (2.26): the server's, each process's, PostgreSQL's,
  nginx's and Plone's own numbers (plone.observability's `@@metrics`) to an
  OTLP/HTTP service, tried with Grafana Cloud.
- [x] A ready-made Grafana dashboard (`docs/grafana/plone-in-a-box.json`).
  Publish it on grafana.com's dashboards too, once it has settled. 
- [x] Request timings: `backend-start` adds plone.observability's filters to
  the official image's `zope.ini` at each start. Drop it once the image
  includes them (plone/container-backend#241). Traces too
  then, with the `opentelemetry` extra.
- plone.observability counts every request as anonymous: its pubevent
  subscriber writes the logged-in flag to `request.environ`, which Zope's
  `HTTPRequest` copies from the WSGI environ (`sane_environment`), so the
  middleware never sees it (1.3.1; plone/plone.observability#112). Then add "logged in"
  response times to the dashboard.
- The Collector's image tag (`OTELCOL_IMAGE` in the compose-override helper)
  isn't seen by Dependabot: bump it at each release. A Collector built with
  only the parts we use would also be smaller than contrib (its binary is
  about 150 MB of the 200 MB it maps).
- plone.observability publishes its histograms as separate counters, so
  Grafana shows `_bucket_total` names; suggest standard histograms upstream.
- Then, opt-in: traces for Volto (Node auto-instrumentation through
  `NODE_OPTIONS`), and for the backend if wrapping its WSGI app stays stable
  across image updates.
- [x] Launch fields for logs and graphs (2.26). The Try It StackScripts made
  with `scripts/linode-addon-stackscript.sh` don't have them until they're
  printed and pasted again (optional fields, so they keep working).

## Retire the duplicate Linode StackScript

- [x] Asked Linode support (ticket 27858783) to remove the public StackScript 692002, a duplicate of
  nguyen-plone's 931893. They don't remove public StackScripts, so it's labeled
  `[DEPRECATED] Plone in a Box: use 931893` instead, and keeps running scripts/linode-obsolete-stackscript.sh,
  which sets up the latest release (see step 3 of RELEASING.md).

## Keep the Plone images up to date

- [x] **Automatic updates** (2.12): `plone-update`, weekly through `plone-update.timer`, on by default. Newer images
  of the same tags only, after a database dump, with a rollback if the site doesn't come back; failed builds are
  skipped. Reports go to the login message, and by email through the site's own mail settings.
- [x] **Plone hotfixes**, documented (setup guide, "Updates").
- [x] **Older servers** (2.12): `src/add-updates.sh` installs `plone-update` on servers set up with 2.0–2.11.
- [x] **Notification URL** (2.12): ntfy, or Slack, Discord, Google Chat, Mattermost and Microsoft Teams webhooks.

## Support custom Plone projects (e.g. from cookieplone)

Keep the official `plone/plone-backend` and `plone/plone-frontend` images as the default, so most people
still deploy with no build step. Add optional settings for people who need more:

- [x] **Custom frontend image.** `FRONTEND_IMAGE`, with ready-made images built in this repository (2.11).
- [x] **Self-built frontend images, documented.** Fork, add a matrix entry, and GitHub Actions builds and
  publishes it (`frontend-image/README.md`).
- [x] **Custom backend image, documented** for a running server: build on `plone/plone-backend`, and change the
  backend's `image:` line (setup guide, "Custom backend image").
- [x] **Custom backend image setting** (2.21): `BACKEND_IMAGE` in every route, checked at setup with a
  fallback to the official backend, covered by `plone-update`. Tested with kitconcept's intranet distribution
  (`ghcr.io/kitconcept/kitconcept-intranet-backend` and `-frontend`). Private images: a registry username and token
  (2.23).
  - [x] Try It for ready-made images (2.22): catalog keys `frontend_image:` and `backend_image:` instead of
    `packages`, documented in docs/try-it-buttons.md. CI checks that they're public and built for amd64 (and arm64
    with `arm: yes`), and that they expose the official images' ports (2.24). Not checked: which Plone and Volto
    versions they run, which the images don't say in a standard way.
  - [x] **Fall back when a backend image can't create the site** (2.22): on a new server, the official backend on
    a fresh database.
  - **Plone distributions in the catalog** (2026-11-23), each as its own entry, ideally added by its makers:
    kitconcept.intranet (set aside 2026-11-24, to add later: the entry was ready on the try-kitconcept-intranet
    branch, `3.11` and `3.12` both work since 2.22, it fits a 1 GB server, its sample pages are in German, and
    without Solr search works but suggestions and email/phone search don't; tell kitconcept, who may want to own
    the entry), then
    kitconcept-website (`ghcr.io/kitconcept/kitconcept-website-backend`, 2.2; a public website), and
    PortalBrasil Intranet (`ghcr.io/portal-br/intranet-backend` and `-frontend`, 1.0.0; Portuguese; invite the
    portal-br community). Ask kitconcept first: they may want to own the entries (tag, demo roles, hint).
  - [x] **Plone Aurora in the catalog** (2.22): `plone/aurora` pinned to one alpha release, with
    `ghcr.io/collective/plone-in-a-box-backend:6.2-aurora` (backend-image/, built weekly). Still to do: move the
    pinned Aurora release on after trying the next one; drop the newer `plone.restapi` and `plone.volto` from the
    backend image once a Plone 6.2 release ships them (6.2.4?), keeping the profile. Old builds of the backend
    image are deleted like the frontend ones (2.24, scripts/cleanup-images.py). Arm: the backend image
    is built for arm64 too (2.23).
  - Add-ons with a Volto part need this, for example [juizi.dashboard](https://github.com/juizi-com/juizi.dashboard):
    its backend package hides it from Site Setup → Add-ons unless the frontend includes `volto-juizi-dashboard`,
    and (as of 2026-11-19) it isn't on PyPI, so the backend add-ons setting can't install it either.
- [x] **Backend add-ons without a custom build.** Expose the `plone/plone-backend` image's `ADDONS`
  environment variable (pip-installs add-ons at container startup) as an optional setting.
- [x] **Check frontend add-on support.** The `plone/plone-frontend` image can't take Volto add-ons without a
  rebuild; they need a frontend image (see above).
- [x] Update `README.md` and `docs/setup-guide.md` for the new options.

### Why not switch the whole project to cookieplone

A cookieplone project has to be built. Building Volto on the server needs more memory than a small box has
and would push setup well past ~10 minutes. Building in CI means users need a GitHub account, a container
registry and credentials before deploying, which breaks the no-command-line Linode flow. It would also fix
Plone/Volto versions when the project is generated, add template churn to maintain, and overlap the existing
nginx + Compose setup. Custom images as an option get most of the benefit without those costs.

## Demo content for trying Plone

Plone 6.2's starter content is one welcome page, so someone trying Plone has
to make content before they see what it can do. An optional set of demo
content would show it right away: a few pages with different blocks (text,
images, teasers, a listing, a table, a video), a news item and an event, a
folder with images and a file.

- **A choice in the launch form**, such as Starter content: `welcome` (Plone's
  welcome page, as now), `demo` (the demo content) or `no` (empty). Only for
  the standard site: a Plone distribution keeps its own.
- **Loaded with plone.exportimport**, which Plone 6.1 and later have built in,
  from a small export kept in this repository.
- **Ours or freely licensed:** text we write, and images we make or that are
  public domain or CC0, so anyone can use the content on their site.
- **In each language the site can start in,** or at least English first,
  with the rest as people contribute.
- A Try It page for plain Plone with the demo content and a demo login would
  then be the quickest way to show someone Plone.

## A control panel for Plone in a Box™

Like a big control panel for Plone in a Box™, but user friendly: one place to
turn its features on and off and change their settings, instead of commands
over SSH. Backups and offsite copies, the restore test, updates,
notifications, email, logs, graphs, Cloudflare, the demo login, HTTPS, and
restoring a backup.

- **User friendly first:** plain words, not settings names; each switch says
  what it does and what it costs (free, or the service's price); sensible
  choices already filled in; a test button where there's something to test
  (send a test email, a test log line); and a clear way back (turn it off
  again, or restore the backup taken before).

- **Separate from the Plone site**, so it still works when Plone doesn't: that's
  exactly when you need it (restore a backup, see why an update failed, turn
  logs on to find out).
- **Cockpit first** (Ubuntu's own web console for a server): a Plone in a Box™
  page as a Cockpit plugin gets logins, sessions and running commands as
  root without our writing them, starts only when someone opens it (little
  memory on a 1 GB server), and comes with a terminal and the server's logs.
  Try it on a test server first: does it install on Ubuntu 24.04 and 26.04,
  work behind nginx, and can our page be the first thing people see? Our own
  small app behind nginx only if Cockpit doesn't work out.
- **Its own address, `box.example.org`** (the site at `www.example.org`, the
  box it runs in at `box.example.org`), titled "Plone in a Box™ control
  panel". A separate address keeps the browser from mixing the panel with
  the site: a script that got into the site can't use an open panel
  session. It needs one more DNS record; setup checks it and gets the
  certificate once it works. The name can be changed. Sites without a domain
  name get a separate port instead (opened in the Launch Stack template, the
  Terraform plans and the server's firewall). Not a path on the site.
- **Safe by default:** off until you turn it on (`sudo plone-panel on`, or a
  box in the launch form), its own login (not the Plone admin's), only over
  HTTPS, optional two-step login with an authenticator app, repeated failed
  logins blocked, and optionally only from your own address. It can do what
  root can, so it has to be at least as hard to get into as SSH.
- **The same tools underneath:** each switch runs the command it stands for
  (`plone-syslog on`, `plone-otel off`, ...), so the panel, SSH and the launch
  fields always agree.
- **In stages, lowest risk first:** (1) a `status` every command can report
  to a program, and one `plone-status` for the whole server (last backup and
  restore test, last update, disk, what's on), which MCP can use too; (2) a
  status page, read only; (3) switches for logs, graphs, notifications, the
  email test, back up now, a new demo password; (4) the risky ones (restore,
  Cloudflare, HTTPS, updates), each with a warning and a way back; (5) a link
  from Plone's Site Setup.

## MCP for Plone in a Box™

Let an AI assistant (Claude and others) help look after a site, through the
Model Context Protocol (MCP): ask "is my site healthy?", "when was the last
backup?", "why did last night's update fail?", and have it answer from the
server itself.

- **The server:** an MCP server on the box with the same tools underneath as
  the control panel (above): status, backups, the restore test, updates, logs,
  graphs. Read-only first; anything that changes the site (restore, turn
  something off) only with your say-so, and a way back.
- **The site's content:** editing pages and finding content through
  plone.restapi. Look first for an MCP server the Plone community already has
  or is building, and use that rather than our own.
- **Safe by default:** off until you turn it on, its own token, only over
  HTTPS, and nothing an assistant does that SSH couldn't undo. Consider the
  separate-service question as for the control panel, so it still works when
  Plone doesn't.

## To investigate

- [x] **Easy HTTPS without your own domain** (2.21): a Let's Encrypt certificate for the server's IP address, so
  the site is at `https://<ip>`, renewed twice a day by `plone-https-ip.timer`. (The sslip.io idea wasn't needed:
  its users would have shared one Let's Encrypt quota.)
- [x] **Email reputation.** Through a relay, receivers judge the relay's IP, which the relay watches; the site owner
  controls the domain's reputation (DMARC reports, Google Postmaster Tools). Cloud providers reuse IP addresses, so
  a new server may inherit a blocklisted one. Idea: check the server's IP and the sending domain against public
  blocklists (Spamhaus and others) at setup and in `plone-update`, and say so in the update report.
  Done in 2.23: blocklist checks at setup (domains and IP address) and weekly (domains). A Spamhaus DQS key setting (2.24) lets
  them ask Spamhaus from providers whose DNS resolvers it refuses (Hetzner, DigitalOcean).
- [x] **Tell site owners about Plone releases and security fixes** (2.18: security posts from the Plone forum,
  daily; patch releases and new versions were already in the weekly update report). Still open: end-of-support
  notices, once there's a reliable source for the dates.
- [x] **Backups off the server** (2.20): `plone-offsite` sends encrypted copies of the nightly backups to
  S3-compatible storage. The server's settings (`/opt/plone` and the nginx site) are
  saved next to each backup, and the update report warns when the newest backup is more than two days old. AWS
  server backups (2.24): Terraform `backups` (daily EBS snapshots through Data Lifecycle Manager), and the console
  steps for Launch Stack servers, documented. Not in the template, which would then need IAM acknowledgment.
- [ ] **OpenTelemetry.** Decided for the release after 2.25: see "OpenTelemetry, and launch fields for logs"
  above. Logs went first, as syslog (2.25, `plone-syslog`).
- [ ] **Other Plone best practices.** Review the box against current Plone deployment recommendations
  (backups, monitoring, security headers, upgrades) and note any gaps. Partly done in 2.24, from running three
  production sites: restarts after security updates, disk warnings, notices when a tool is cut off, backup problems
  by email, SSH keys only and fail2ban, and the guide's uptime checks and outgoing ports. In 2.25: a monthly
  restore test, the server's own mail, logs to a syslog service, `plone-cloudflare`, DigitalOcean's free alerts
  from Terraform, and the GitHub Actions pinned to commit hashes. Still open: review the
  security headers against current recommendations, and moving to a new Plone version (6.3) still takes a person.
- [ ] **More add-ons in the catalog.** Suggest Plone and Volto add-ons that work on a box, and invite their
  authors to add a Try It page (`addons.yml`, see docs/try-it-buttons.md), for example starting from
  [Awesome Volto](https://github.com/collective/awesome-volto). As of November 2026 it is still maintained but
  changes rarely, mostly link fixes, so check entries before recommending them.
- [x] **Volto Light Theme** (2.11): the ready-made image `ghcr.io/collective/plone-in-a-box-frontend:19-vlt`.
