# Releasing Plone in a Box™

`tkimnguyen/plone-in-a-box` is where development happens. `collective/plone-in-a-box` is kept in sync after each
release, and the public Linode StackScript is updated by hand.

## 1. Make and test the changes

1. Work on a branch and open a pull request into `main`. CI (ShellCheck, `terraform fmt`, `terraform validate`,
   `cfn-lint`) must pass.
2. Test the changed script before merging:
   * **Linode**: paste `src/StackScript` from the branch into the private test StackScript (`plone-in-a-box-test`,
     Target Images Ubuntu 24.04 and 26.04) and deploy a 1 GB Linode (Nanode) from it, the smallest size the docs recommend.
   * **AWS** (if `src/aws/` or the script changed): `terraform apply -var release=<branch>` from `src/aws/` on the
     branch. The server downloads `src/StackScript` from GitHub, so push the branch first; without `release` it
     runs the last release's script, not the branch's.
   * **DigitalOcean** (if `src/digitalocean/` or the script changed): the same, from `src/digitalocean/`.
   * **Hetzner** (if `src/hetzner/` or the script changed): the same, from `src/hetzner/`.
   * **AWS Launch Stack** (if `src/aws/cloudformation.yaml` changed): in the CloudFormation console, **Create stack →
     With new resources → Upload a template file**, choose the branch's `src/aws/cloudformation.yaml`, and set
     **Plone in a Box release** to the branch name if the script changed too. Delete the stack afterwards. Or let
     `scripts/test-deploy.sh aws --cloudformation --ref <branch>` create the stack from the branch's template, with
     the release set to the commit tested, run the usual checks, and delete it.
   * Checks on each test server:
     * right after creating the server, its address shows the setup progress page, which turns into the site
     * `/root/plone-credentials.txt` exists, the site loads, and `admin` can log in with the generated password
     * deploy once more with **Plone admin password** set: `admin` logs in with that password, and the credentials
       file doesn't contain it
     * `sudo plone-reset-admin-password` changes the password, and the new one works
     * from outside, ports 5432, 8080 and 3000 time out (`nc -zv -w 5 <ip> <port>`)
     * after `docker compose --project-directory /opt/plone up -d --force-recreate backend`, the same password
       still works
   * Delete the test servers afterwards: Terraform protects them, so follow "Removing the box" in the setup guide
     (on AWS and Hetzner `terraform apply -var deletion_protection=false`; then `prevent_destroy = false` in
     `main.tf` and `terraform destroy` with the same `-var` options), and put `prevent_destroy = true` back before
     committing.
   * Or let `scripts/test-deploy.sh linode --ref <branch>` (or `digitalocean`, `aws` or `hetzner`) do the test: it
     creates a server (1 GB on Linode and DigitalOcean, `t3.small` on AWS, CPX02 (1 GB) on Hetzner) with the launcher or StackScript from the branch,
     runs these checks plus a restart, and deletes the server (about 15 minutes). Add
     `--generated-password` for the generated-password check, and `--addons collective.easyform` (plus, in a
     second run, `--addons "collective.easyform no-such-package-xyz" --expect-addons-skipped`) if add-ons changed. Add `--keep-on-failure` to keep the server when
     a check fails, so you can look at it or retry the check without waiting for a new one.
     `scripts/test-deploy.sh cleanup linode` deletes any test servers left behind. See [Automated test deploys](#automated-test-deploys) for the one-time setup.
3. Merge the pull request.

### Automated test deploys

One-time setup for `scripts/test-deploy.sh`:

* **SSH key** for test servers only: `ssh-keygen -t ed25519 -f ~/.ssh/piab_test_ed25519 -C piab-test -N ''`
* **Linode**: in the tknguyen2 account, the restricted user `piab-test` (Identity & Access) has only the roles
  `account_linode_creator`, `account_stackscript_creator` and the default viewer roles, so it can create servers
  but can't touch existing Linodes or the public StackScript. As `piab-test`:
  * a private StackScript `plone-in-a-box-test` (Target Images: Ubuntu 24.04 and 26.04); the script overwrites it each run
  * a personal access token (Linodes Read/Write, StackScripts Read/Write, Events Read Only, 1-month expiry),
    stored with `security add-generic-password -a "$USER" -s piab-linode-token -w`
* **DigitalOcean**: a team `piab-test` used only for tests, so its token can't reach any other Droplets (team
  switcher → **Create a team**). In it, **API → Tokens → Generate New Token** with custom scopes `droplet`
  create/read/update/delete, `ssh_key` create/read/update/delete, `tag` create/read/delete, `firewall`,
  `monitoring` and `uptime` create/read/update/delete, and read for `account`, `actions`, `regions`, `sizes`,
  `image`, `snapshot` and `vpc` (90-day expiry; the Terraform test needs `firewall`, `monitoring`, `uptime` and
  `account`), stored with
  `security add-generic-password -a "$USER" -s piab-do-token -w`. The first run adds the SSH key to the team as
  `piab-test`.
* **Hetzner**: in the [Hetzner Console](https://console.hetzner.com), a project `piab-test` used only for tests, so its
  token can't reach any other servers. In it, **Security → API tokens → Generate API token** (Read & Write), stored
  with `security add-generic-password -a "$USER" -s piab-hetzner-token -w`. The first run adds the SSH key to the
  project as `piab-test`. Set `PIAB_HETZNER_SERVER_TYPE` to an Arm type (`cax…`) to test Arm.
* **AWS**: install the AWS CLI (`brew install awscli`). In IAM, create a user `piab-test` with no console access
  and one inline policy, the contents of [`scripts/aws-test-policy.json`](scripts/aws-test-policy.json): it can
  launch, restart and terminate only instances tagged `piab-test`, and create only `piab-test` key pairs (one per
  computer, named `piab-test-<fingerprint>`) and the `piab-test` security group. Create an access key for it (use case: Command Line Interface) and store both parts:
  `security add-generic-password -a "$USER" -s piab-aws-access-key-id -w` and
  `security add-generic-password -a "$USER" -s piab-aws-secret-access-key -w`. Tests run in `us-east-1` unless
  `PIAB_TEST_REGION` is set; the first run in a region adds the key pair and the security group there.
  For Launch Stack tests, also create a managed policy (IAM → **Policies → Create policy**; the user's inline
  policies are at their size limit) from
  [`scripts/aws-test-cloudformation-policy.json`](scripts/aws-test-cloudformation-policy.json), and attach it to
  `piab-test`. It allows only stacks named `piab-test-*`. Create test stacks with the stack tag `piab-test=true`
  (`aws cloudformation create-stack --tags Key=piab-test,Value=true`), so their instance and Elastic IP carry it;
  `scripts/test-deploy.sh aws --cloudformation` does this, and `list` and `cleanup` include such stacks.
* **Chat notices**, for `scripts/test-notify.sh`, which sends sample update notices to real channels when the
  notify script changes: a webhook in a test channel per service, stored as `piab-webhook-<service>`
  (`teams`, `slack`, `discord`, `gchat`, `mattermost` or `ntfy`). Copy the URL, then
  `security add-generic-password -U -a "$USER" -s piab-webhook-teams -w "$(pbpaste)"`; the interactive `-w`
  prompt cuts input off at 128 characters, too short for Teams. Where to create them:
  * Teams: the channel's **•••** menu → **Workflows** → **Send webhook alerts to a channel**
  * Slack: [api.slack.com/apps](https://api.slack.com/apps) → **Create New App** → **Pick features**, with only the
    `incoming-webhook` scope and no events → **Create and Install** → pick the channel → **Allow**; the URL is
    under **Incoming Webhooks**
  * Discord: the channel's **Edit Channel** → **Integrations** → **Create Webhook**, then click it → **Copy Webhook URL**
    (on a community server, make the test channel private first)
  * Google Chat (Google Workspace only): the space's name → **Apps & integrations** → **Add webhooks** → **Save**
  * Mattermost: **Integrations → Incoming Webhooks → Add Incoming Webhook**. Without a server, a throwaway one
    works: `mattermost/mattermost-preview` in Docker behind Caddy at `<ip-with-dashes>.sslip.io` (for HTTPS) on a
    2 GB test server; the first user created is the admin
  * ntfy: `https://ntfy.sh/<a long random topic>`

* **Logs and graphs**, for `--logs` and `--metrics` (the launch fields of 2.26): a log service's source and an
  OpenTelemetry service's account (Better Stack's and Grafana Cloud's free plans are enough). Set
  `PIAB_TEST_LOG_SERVER` (HOST:PORT), `PIAB_TEST_METRICS_ENDPOINT` and `PIAB_TEST_METRICS_USER`, and store the log
  service's token element (`[logtail@11993 source_token="..."]` for Better Stack) as `piab-log-token` and the
  OpenTelemetry token as `piab-metrics-token`.

Tokens stay in the macOS Keychain; never paste them into chats or commit them. Remove one with
`security delete-generic-password -s piab-linode-token` (or `piab-do-token`, `piab-hetzner-token`, the two AWS
entries or a `piab-webhook-<service>`). Deactivate
the AWS access key in IAM when it's not needed; it doesn't expire by itself.

## 2. Release

1. In `CHANGES.md`, replace `(unreleased)` with today's date, and add a few plain sentences for site owners above
   the list of changes; they become the Discord notice ([below](#one-time-setup-of-the-discord-notice)). If `src/StackScript` changed, set the new version in
   `PIAB_RELEASE` in `src/user-data.sh`, the `Release` parameter's `Default` in `src/aws/cloudformation.yaml`, the
   `release` variable's `default` in `src/aws/main.tf`, `src/hetzner/main.tf` and `src/digitalocean/main.tf`, and
   the three-line launchers in `README.md`, `docs/setup-guide.md` and `docs/try-it-buttons.md` (the `.../plone-in-a-box/<version>/src/StackScript`
   URL), so pasted launchers and the Launch Stack button download it, and run `python3 scripts/catalog.py pages` so the
   start page (`docs/index.html`) and the Try It pages in `docs/try/` name it too. CI checks that they all match. Update the slides too
   (`docs/slides/plone-in-a-box.md`): the release number and month on the title slide, new features on their slides,
   and "What's next". Rebuild `docs/slides/plone-in-a-box.html` with Marp (`marp --html docs/slides/plone-in-a-box.md
   -o docs/slides/plone-in-a-box.html`), and render the slides to PNG (`--images png`) to check nothing overflows.
   Open a pull request with these changes (a `release-<version>` branch), and merge it once CI passes. `main`
   takes changes only through pull requests; an account that can bypass that rule still shouldn't push to it.
2. On GitHub, go to **Releases → Draft a new release**. Create a tag on `main` named after the version, without a
   `v` (for example `2.1`), set the title to `Plone in a Box 2.1`, and summarize the changes. End the notes with
   the invitation to the Discord channel: `Questions or ideas? Join [#plone-in-a-box](https://discord.com/channels/786421998426521600/903993234248835082) on the
   [Plone Discord](https://discord.gg/jRrsnYkNvS).` The channel name opens the channel for people already in the Plone
   Discord, and "Plone Discord" is the invite that brings newcomers in. (The invite is set never to expire; Discord's default is 7
   days, so a replacement must be set to never expire too.)


3. Publishing the release also publishes `src/aws/cloudformation.yaml` for the **Launch Stack** button, which opens
   `https://plone-in-a-box-templates.s3.us-east-1.amazonaws.com/latest/cloudformation.yaml`:
   `.github/workflows/publish-template.yml` uploads it to `latest/` and to a folder named after the version (for
   example `2.14/`), and checks both. Approve its `aws-templates` deployment in the release's Actions run if asked.
   Then click the button in the README and check that the form shows the new version's defaults. To publish a
   release's template again: **Actions → Publish template → Run workflow**.

   By hand, if the workflow can't run: in the AWS console (Plone Foundation account), **S3 →
   plone-in-a-box-templates**, upload the release's `src/aws/cloudformation.yaml` into `latest/` and into
   `<version>/`.

### One-time setup of the template upload

The workflow signs in to AWS with GitHub's OpenID Connect token, so no AWS keys are stored. In the AWS console (Plone
Foundation account):

1. **IAM → Identity providers → Add provider**, if `token.actions.githubusercontent.com` isn't listed: **OpenID
   Connect**, provider URL `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
2. **IAM → Roles → Create role → Custom trust policy**: paste
   [`scripts/aws-templates-role-trust.json`](scripts/aws-templates-role-trust.json), replacing `ACCOUNT_ID` with the
   account's 12-digit number (top right menu). It trusts only this repository's jobs in the `aws-templates`
   environment. **Next**, skip the permissions list, **Next**, name it `piab-publish-templates`, **Create role**.
3. Open the role → **Add permissions → Create inline policy → JSON**: paste
   [`scripts/aws-templates-role-policy.json`](scripts/aws-templates-role-policy.json) (it can only write
   `cloudformation.yaml` files in the bucket), name it `publish-templates`, **Create policy**. Copy the role's
   **ARN**.
4. On GitHub, in tkimnguyen/plone-in-a-box: **Settings → Environments → New environment** `aws-templates`; under
   **Deployment branches and tags**, choose **Selected branches and tags** and add the tag rule `[0-9]*` and the
   branch `main`. Optionally add yourself as a required reviewer. Then **Settings → Secrets and variables → Actions
   → Variables → New repository variable** `AWS_TEMPLATE_ROLE_ARN`, with the role's ARN.
5. To check it: **Actions → Publish template → Run workflow** publishes the latest release's template again.

### One-time setup of the template bucket

In the AWS console (Plone Foundation account), region **US East (N. Virginia) us-east-1**:

1. **S3 → Create bucket** in the **Global namespace**, named `plone-in-a-box-templates`. Under **Block Public Access
   settings for this bucket**, untick only the two settings about bucket and access point **policies**, keep the
   two about **ACLs** ticked, and confirm. Leave everything else as is (Object Ownership: ACLs disabled).
2. Open the bucket → **Permissions → Bucket policy → Edit**, paste this, and save:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Sid": "PublicReadTemplates",
       "Effect": "Allow",
       "Principal": "*",
       "Action": "s3:GetObject",
       "Resource": "arn:aws:s3:::plone-in-a-box-templates/*"
     }]
   }
   ```
   Everything in this bucket is public, so only put CloudFormation templates in it.

### One-time setup of the Discord notice

When a release's tag reaches collective/plone-in-a-box (the last step of [syncing](#4-sync-collectiveplone-in-a-box)),
`.github/workflows/release-notice.yml` posts a notice to the Discord channel #plone-in-a-box, linking to the GitHub
release. Only the latest release is announced, never a draft or pre-release.

The notice's text is the release's section of `CHANGES.md`: the paragraphs above its list of changes, if there are
any, or else the list. Those paragraphs are for site owners, not developers, so write them when dating the release:
a few plain sentences on what's new for someone running a site, without setting or file names. For example:

```
2.14 (2026-11-22)
-----------------

When you let people try your site, you can now choose the demo login's
password yourself, and give it just the roles it needs, ...

- Demo login roles: ...
```

1. In Discord, on the #plone-in-a-box channel: **Edit Channel → Integrations → Webhooks → New Webhook**, name it
   `Plone in a Box releases`, and **Copy Webhook URL**.
2. On GitHub, in **collective/plone-in-a-box**: **Settings → Secrets and variables → Actions → New repository
   secret**, named `DISCORD_WEBHOOK_URL`, with that URL as its value.
3. To check it: **Actions → Release notice → Run workflow** posts the latest release's notice again.

The webhook URL lets anyone post to the channel, so keep it only in that secret. If it leaks, delete the webhook in
Discord and create a new one.

## 3. Update the public Linode StackScript

The public **Plone in a Box** StackScript is [931893](https://cloud.linode.com/stackscripts/931893), owned by
**nguyen-plone**; the README and setup guide link to it. `scripts/update-public-stackscripts.sh` updates it, the
Juizi Dashboard one (2318969, also nguyen-plone's) and the obsolete copy (692002, tknguyen2's) through Linode's API,
each made from the release's tag:

```
scripts/update-public-stackscripts.sh 2.14            # what would change, and the form fields
scripts/update-public-stackscripts.sh 2.14 --apply    # update them, with the note "2.14: Plone in a Box 2.14"
```

Add `--note "demo login password and roles"` for a more useful revision note. It checks each StackScript's owner and
that it's public before changing it, and that Linode has exactly the new script afterwards. It doesn't change
**Target Images**: when a release supports a new Ubuntu version, add it in Cloud Manager.

One-time setup: log in to Cloud Manager as **nguyen-plone**, **Profile → API Tokens → Create a Personal Access
Token**: label `piab-stackscripts`, expiry 1 month (or longer), **StackScripts Read/Write** and every other scope
**No Access**. Store it with `security add-generic-password -a "$USER" -s piab-linode-nguyen-plone -w`. Do the same
as **tknguyen2**, stored as `piab-linode-tknguyen2`. These StackScripts run as root on other people's servers, so
keep the tokens only in the Keychain, never in GitHub, and revoke them in Cloud Manager if in doubt.

By hand instead:

1. Log in to Cloud Manager as **nguyen-plone**.
2. **StackScripts → Account StackScripts → ⋯ → Edit** on **Plone in a Box** (not the private
   `plone-in-a-box-test`, which `scripts/test-deploy.sh` overwrites).
3. Replace the **Script** with
   https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/StackScript, check that **Target Images**
   includes the Ubuntu release the script supports, and enter a revision note such as `2.1: <summary>`.
4. Save, then confirm **Last Revision** shows today's date. (Community StackScripts leaves out your own
   account's StackScripts, so check it there from another account.)

An older public copy, 692002 owned by **tknguyen2**, stays listed: Linode support confirmed (ticket 27858783, November
2026) that public StackScripts are never removed, since people may rely on them. Its label says
`[DEPRECATED] Plone in a Box: use 931893`, and its description points to 931893. It runs
[`scripts/linode-obsolete-stackscript.sh`](scripts/linode-obsolete-stackscript.sh), which says it's obsolete (in the
setup log and the login message), points to 931893, and sets up the latest release, so it doesn't need updating at
each release. Its form fields are those of 2.16; if a release adds a field, copy the new `# <UDF` lines into the
script and paste it into 692002 again.

Public StackScripts can't be deleted or made private, not even by Linode support; only their label, description and
script can change.

### Per-add-on StackScripts

The "Try It" StackScripts for single add-ons ([docs/try-it-buttons.md](docs/try-it-buttons.md)), printed by
`scripts/linode-addon-stackscript.sh`, download the latest release, so they don't need updating at each release.
If a release adds or changes a form field (a `# <UDF` line in `src/StackScript`), print each one again with the same
options and paste it over the old one. Test one first with
`scripts/test-deploy.sh linode --linode-script <file>` (print it with `--ref <branch>` to test unreleased changes).

## 4. Sync `collective/plone-in-a-box`

One-time setup on your machine:

```
git remote add collective git@github.com:collective/plone-in-a-box.git
```

After each release:

```
git checkout main && git pull
git push collective main:sync-from-tkimnguyen
```

Open https://github.com/collective/plone-in-a-box/compare/main...sync-from-tkimnguyen, create the pull request,
merge it once CI passes, and delete the `sync-from-tkimnguyen` branch. Then push the release tag (for example
`2.4`) so `collective` has every version:

```
git fetch --tags origin
git push collective <version>
```

Pushing the tag announces the release on Discord (see [the Discord notice](#one-time-setup-of-the-discord-notice)).

Then copy the GitHub release, with its notes, so `collective` shows it too (its Releases list, and **Watch →
Releases** for people who follow it there):

```
v=<version>
{ gh release view "$v" --json body -q .body
  printf '\n\n---\n\n<sub>Mirrored from [tkimnguyen/plone-in-a-box %s](https://github.com/tkimnguyen/plone-in-a-box/releases/tag/%s), where the downloads and the Launch Stack template come from.</sub>\n' "$v" "$v"; } > /tmp/notes.md
gh release create "$v" --repo collective/plone-in-a-box --verify-tag --title "Plone in a Box $v" --notes-file /tmp/notes.md
```

Edit release notes on `tkimnguyen/plone-in-a-box` only, then copy them again (`gh release edit "$v" --repo
collective/plone-in-a-box --notes-file /tmp/notes.md`). The copy doesn't publish the template a second time:
`publish-template.yml` runs only in `tkimnguyen/plone-in-a-box`, and the Discord notice comes from the tag, not
the release.

Avoid committing directly to `collective`, so these pull requests stay simple fast-forwards. If someone does
contribute there, bring it into this repo first with `git pull collective main`.

Pushing needs an SSH key added to GitHub (`ssh -T git@github.com` should greet you by name). HTTPS pushes with a
password are rejected.

## 5. Announce it on the Plone forum

Once the Discord notice is out, post the release in the forum thread
[github/collective/plone-in-a-box: an easy way to deploy a secure cloud server](https://community.plone.org/t/github-collective-plone-in-a-box-an-easy-way-to-deploy-a-secure-cloud-server/23310),
so people who aren't on Discord hear about it too. Use the summary for site owners from `CHANGES.md`, with links to
the GitHub release and the slides (https://collective.github.io/plone-in-a-box/slides/), and thank anyone who
contributed, with their forum handle.
