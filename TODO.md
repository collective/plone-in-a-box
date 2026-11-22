# TODO

## Automated test deploys

`scripts/test-deploy.sh` runs the Linode, DigitalOcean, AWS and Hetzner tests (see RELEASING.md). Still open:

- [ ] Renew the tokens when they expire (Linode: 1 month, DigitalOcean: 30 days), and rotate the AWS access key.

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
- [ ] **Custom backend image setting** (for example a cookieplone project's backend), like `FRONTEND_IMAGE`.
  - Decide how private registries authenticate (registry URL, username and token as optional fields?).
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

- [ ] **Easy HTTPS without your own domain.** Sites without a domain are plain HTTP, so passwords (including Try It
  demo logins) cross the network unencrypted. Idea: an automatic `<ip-with-dashes>.sslip.io` hostname with a Let's
  Encrypt certificate. Check Let's Encrypt's limit of about 50 new certificates a week per registered domain: unless
  sslip.io is on the Public Suffix List, all its users share one quota. A Plone in a Box subdomain service would
  share one too, unless its parent domain is on that list. Alternatives: a rate-limit increase, another ACME CA
  (ZeroSSL, Google Trust Services), Cloudflare Tunnel.
- [ ] **Email reputation.** Through a relay, receivers judge the relay's IP, which the relay watches; the site owner
  controls the domain's reputation (DMARC reports, Google Postmaster Tools). Cloud providers reuse IP addresses, so
  a new server may inherit a blocklisted one. Idea: check the server's IP and the sending domain against public
  blocklists (Spamhaus and others) at setup and in `plone-update`, and say so in the update report.
- [ ] **Tell site owners about Plone releases and security fixes.** `plone-update` installs patch releases of the
  versions a site runs, but owners aren't told about announcements: security hotfixes, new Plone versions they'd move
  to themselves (such as 6.3), or end of support. Idea: follow the standard Plone announcements (the announcements
  list, or what replaces it; it may change soon) and pass them on through what the box already has: the
  notification URL, email through the site's mail settings, and the login message. Decide whether each server
  checks a feed itself (e.g. weekly with `plone-update`), or this project relays announcements to its own channel,
  and how to avoid repeats.
- [ ] **OpenTelemetry.** Whether to offer tracing and metrics for the backend, frontend and nginx, and where
  the data would go on a single small server.
- [ ] **Other Plone best practices.** Review the box against current Plone deployment recommendations
  (backups, monitoring, security headers, upgrades) and note any gaps.
- [ ] **More add-ons in the catalog.** Suggest Plone and Volto add-ons that work on a box, and invite their
  authors to add a Try It page (`addons.yml`, see docs/try-it-buttons.md), for example starting from
  [Awesome Volto](https://github.com/collective/awesome-volto). As of November 2026 it is still maintained but
  changes rarely, mostly link fixes, so check entries before recommending them.
- [x] **Volto Light Theme** (2.11): the ready-made image `ghcr.io/collective/plone-in-a-box-frontend:19-vlt`.
