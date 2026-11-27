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

- An optional OTLP endpoint and key: when set, an OpenTelemetry Collector
  container sends the server's metrics (CPU, memory, disk, network), each
  container's, PostgreSQL's and nginx's, and optionally the containers' logs.
  Nothing changes in Plone or Volto. Guide: Grafana Cloud's free tier, with a
  dashboard.
- Then, opt-in: traces for Volto (Node auto-instrumentation through
  `NODE_OPTIONS`), and for the backend if wrapping its WSGI app stays stable
  across image updates.
- Launch fields for the syslog server (`plone-syslog`, 2.25) and the OTLP
  endpoint together, in one optional "Logs and metrics" section, so the
  launchers and the Try It StackScripts change once.

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
