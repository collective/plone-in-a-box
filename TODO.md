# TODO

## Automated test deploys

Let test deploys run without manual steps in Cloud Manager and the DigitalOcean control panel: create the test
server, watch the progress page, run the checks over SSH, reboot, check again, and delete it.

- [ ] **Tokens**, stored in the macOS Keychain (never pasted into chats or committed):
  - Linode personal access token `claude-code-testing`, 1-month expiry, scopes Linodes Read/Write,
    StackScripts Read/Write, Events Read Only, everything else No Access. Created in the account that owns the
    private `plone-in-a-box-test` StackScript. Keychain: `security add-generic-password -a "$USER" -s piab-linode-token -w`
  - DigitalOcean token, 30-day expiry, custom scopes `droplet` create/read/delete, `ssh_key` create/read,
    `tag` create/read. Keychain: `security add-generic-password -a "$USER" -s piab-do-token -w`
- [ ] A dedicated SSH key for test servers only (`~/.ssh/piab_test_ed25519`).
- [ ] Safeguards: name and tag every test server `piab-test-…` and only ever touch servers with that tag. Neither
  provider can limit a token to particular servers, so consider a separate test account (or a DigitalOcean team)
  with no production servers in it.
- [ ] Claude Code permission rules for `api.linode.com` and `api.digitalocean.com` if the permission check blocks
  creating or deleting test servers.
- [ ] Optionally, turn the steps into a script in the repo (for example `scripts/test-deploy.sh linode|digitalocean
  <branch>`) that runs the checks from RELEASING.md, so anyone can repeat them.
- [ ] Delete or let the tokens expire when not in use; remove the Keychain entries with
  `security delete-generic-password -s piab-linode-token` (and `piab-do-token`).

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

## Support Hetzner Cloud

- [ ] **No command line:** in the Hetzner Cloud Console's **Create server** page, choose Ubuntu 24.04 and paste
  `src/user-data.sh` into the **Cloud config** (user data) box, like DigitalOcean and AWS. Check that the launcher
  works there unchanged, and which plan is the smallest that's comfortable.
- [ ] **Terraform:** `src/hetzner/main.tf` with the `hcloud` provider (server, SSH key, Hetzner Firewall allowing
  only TCP 22, 80 and 443), running the same script as user data, with the same variables as the AWS and
  DigitalOcean configurations. Add it to the CI matrix.
- [ ] How to read or reset the admin password without SSH (the Cloud Console's browser console), the server's
  address for a domain (Primary IPs), and backups/snapshots.
- [ ] README, setup guide ("Option D: Hetzner"), RELEASING.md test steps, and a test deploy (both routes; amd64
  and Arm plans).

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
