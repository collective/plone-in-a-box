# TODO

## Automated test deploys

`scripts/test-deploy.sh` runs the Linode, DigitalOcean, AWS and Hetzner tests (see RELEASING.md). Still open:

- [ ] Renew the tokens when they expire (Linode: 1 month, DigitalOcean: 30 days), and rotate the AWS access key.

## Retire the duplicate Linode StackScript

- [ ] Ask Linode support (from the tknguyen2 account) to remove the public StackScript 692002, a duplicate of
  nguyen-plone's 931893. Once it's gone, drop it from step 3 of RELEASING.md.

## Keep the Plone images up to date

Ubuntu installs its security updates automatically, nginx's included, but nothing updates the Docker images. A site
whose owner never logs in stays on the Plone, Volto and PostgreSQL patch release it was set up with, even though the
floating tags (`plone/plone-backend:6.2`, `plone/plone-frontend:19`, `postgres:17`) move on. Today the fix is a manual
`docker compose pull` and `up -d` (setup guide, "Day-to-day administration").

- [ ] **Tell the admin when newer images exist.** A daily systemd timer compares the local image digests with the
  registry (`docker compose pull --dry-run`, or the registry API), and writes the result to the login message
  (`/etc/update-motd.d/`), for example "Newer Plone images are available: run `sudo plone-update`". It changes
  nothing, so it can be on by default. Also a `plone-update` command that takes a database dump, then runs `pull`
  and `up -d`.
- [ ] **Optional automatic image updates.** A setting (`AUTO_UPDATE_IMAGES`, off by default) for a weekly timer that
  runs `plone-update` at night. Questions to settle first:
  - Only within the configured tags, never across Plone, Volto or PostgreSQL releases. PostgreSQL within a major
    version only.
  - Keep the previous images and the last dump, and roll back if the backend's health check fails after the update.
  - Where to report what happened: the login message, the setup log, an email?
  - A ready-made frontend image's backend add-on is pinned by its labels. Re-read the labels after a pull, so a
    rebuilt image with a newer add-on version doesn't get out of step with the backend.
- [ ] **Plone hotfixes.** Document adding a `Products.PloneHotfix…` package to `ADDONS` when the Plone security
  team publishes one, and link to the security announcements (plone.org/security).

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
