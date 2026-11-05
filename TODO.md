# TODO

## Finish OS updates during setup

New servers come up with Ubuntu updates still pending and "System restart required" on the login banner.

- [ ] `src/StackScript`: use `apt-get full-upgrade` instead of `apt-get upgrade`, so updates that need new
  packages (such as a new kernel) are installed too.
- [ ] At the end of setup, reboot once if `/var/run/reboot-required` exists. The containers restart on their own;
  make sure the progress page and the console login banner still make sense around the reboot.
- [ ] Setup guide: tell people to run `sudo apt update && sudo apt full-upgrade -y` and `sudo reboot` now and
  then (the site is down for a minute or two), and not to run `do-release-upgrade`.

## Enough swap on 1 GB Linodes

`src/StackScript` adds a 2 GB swap file only when the server has no swap at all. Linode servers come with a 512 MB
swap disk, so a 1 GB Linode never gets the swap file: in testing (Plone 6.2 / Volto 19, idle) it had about 424 MB of
RAM and 206 MB of swap free, versus about 2.1 GB of headroom on a 1 GB DigitalOcean Droplet with the swap file.

- [ ] Add the swap file whenever RAM plus existing swap is under about 3 GB, not only when there's no swap.
- [ ] Test on a 1 GB Linode (Nanode) and check `free -m` shows the extra swap; then the docs could say 1 GB works
  on Linode too.

## Move to Ubuntu 26.04 LTS

- [ ] Ubuntu 26.04 LTS ("Resolute Raccoon") was released on 2026-04-23 (26.04.1 is out), supported until
  2031-05. Plone in a Box targets 24.04, which is supported until 2029-05. To switch:
  - `src/aws/main.tf`: change the AMI name filter (`ubuntu-noble-24.04-amd64-server-*`) to the 26.04 image
    name, and check the `hvm-ssd-gp3` path still matches Canonical's naming.
  - `src/digitalocean/main.tf`: change `image` from `ubuntu-24-04-x64` to the 26.04 slug.
  - Linode: add Ubuntu 26.04 to the public StackScript's Target Images.
  - `src/StackScript`: update "Tested target", and check the Docker install, nginx, ufw, certbot and the
    progress page on 26.04.
  - Update the README, setup guide (including the DigitalOcean launcher instructions) and the launcher's comment.
  - Test a fresh deploy on each provider. Decide whether to keep 24.04 working too.

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
