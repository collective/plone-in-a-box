# TODO

## Update default versions

- [ ] **Switch the defaults to Plone 6.2 and Volto 19.** Volto 19 has a final release (19.6.1 as of 2026-11-05),
  which is when the README said to switch. Plone 6.1 bug-fix releases ended on 2026-06-25 (security fixes
  continue until 2027-12-31); 6.2 is supported until 2028-06-30. Change `PLONE_VERSION` / `VOLTO_VERSION` in
  `src/StackScript` (UDF defaults and fallbacks), `src/aws/main.tf`, `src/digitalocean/main.tf` and
  `src/digitalocean/user-data.sh`, update the README and setup guide, and test a fresh deploy on each provider.
  Then set `PIAB_RELEASE` in the launcher to the release that includes the change.

## Clean up old images and snapshots

- [ ] Check the AWS and DigitalOcean accounts for images or snapshots used with the previous version of
  Plone in a Box™ (for example AMIs and their EBS snapshots, or DigitalOcean snapshots), and delete the ones that
  are no longer needed. Check every AWS region the project was deployed in, since AMIs are per region.

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

A cookieplone project has to be built. Building Volto on the server needs more memory than the 2 GB minimum
and would push setup well past ~10 minutes. Building in CI means users need a GitHub account, a container
registry and credentials before deploying, which breaks the no-command-line Linode flow. It would also fix
Plone/Volto versions when the project is generated, add template churn to maintain, and overlap the existing
nginx + Compose setup. Custom images as an option get most of the benefit without those costs.
