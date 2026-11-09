# TODO

## Automated test deploys

`scripts/test-deploy.sh` runs the Linode and DigitalOcean tests (see RELEASING.md). Still open:

- [ ] The DigitalOcean token can reach every Droplet in the account; only the script's `piab-test` tag check keeps
  it away from other servers. Consider a separate DigitalOcean team with no other Droplets in it for testing.
- [ ] Renew the tokens when they expire (Linode: 1 month, DigitalOcean: 30 days), and rotate the AWS access key.

## Support custom Plone projects (e.g. from cookieplone)

Keep the official `plone/plone-backend` and `plone/plone-frontend` images as the default, so most people
still deploy with no build step. Add optional settings for people who need more:

- [ ] **Custom image names.** Add optional backend and frontend image settings to the StackScript (UDF fields),
  `src/aws/main.tf` and `src/digitalocean/main.tf`. When set, the Compose file uses those images instead of
  the stock ones. This lets someone build a project with cookieplone, push its images to a registry, and run
  them on a box.
  - Decide how private registries authenticate (registry URL, username and token as optional fields?).
  - Document how this interacts with `PLONE_VERSION` / `VOLTO_VERSION` (ignored when custom images are set?).
- [ ] **Backend add-ons without a custom build.** Expose the `plone/plone-backend` image's `ADDONS`
  environment variable (pip-installs add-ons at container startup) as an optional setting.
- [ ] **Check frontend add-on support.** Find out whether the current `plone/plone-frontend` image can take
  Volto add-ons without a rebuild. If not, document that frontend add-ons need custom images.
- [ ] Update `README.md` and `docs/setup-guide.md` for the new options.

### Why not switch the whole project to cookieplone

A cookieplone project has to be built. Building Volto on the server needs more memory than a small box has
and would push setup well past ~10 minutes. Building in CI means users need a GitHub account, a container
registry and credentials before deploying, which breaks the no-command-line Linode flow. It would also fix
Plone/Volto versions when the project is generated, add template churn to maintain, and overlap the existing
nginx + Compose setup. Custom images as an option get most of the benefit without those costs.
