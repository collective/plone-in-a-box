# TODO

## Automated test deploys

`scripts/test-deploy.sh` runs the Linode, DigitalOcean, AWS and Hetzner tests (see RELEASING.md). Still open:

- [ ] Renew the tokens when they expire (Linode: 1 month, DigitalOcean: 30 days), and rotate the AWS access key.

## Retire the duplicate Linode StackScript

- [ ] Ask Linode support (from the tknguyen2 account) to remove the public StackScript 692002, a duplicate of
  nguyen-plone's 931893. Once it's gone, drop it from step 3 of RELEASING.md.

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
