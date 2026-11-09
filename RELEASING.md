# Releasing Plone in a Box™

`tkimnguyen/plone-in-a-box` is where development happens. `collective/plone-in-a-box` is kept in sync after each
release, and the public Linode StackScript is updated by hand.

## 1. Make and test the changes

1. Work on a branch and open a pull request into `main`. CI (ShellCheck, `terraform fmt`, `terraform validate`,
   `cfn-lint`) must pass.
2. Test the changed script before merging:
   * **Linode**: paste `src/StackScript` from the branch into the private test StackScript (`plone-in-a-box-test`,
     Target Image Ubuntu 24.04) and deploy a 1 GB Linode (Nanode) from it, the smallest size the docs recommend.
   * **AWS** (if `src/aws/` or the script changed): `terraform apply` from `src/aws/` on the branch.
   * **DigitalOcean** (if `src/digitalocean/` or the script changed): `terraform apply` from `src/digitalocean/`.
   * **AWS Launch Stack** (if `src/aws/cloudformation.yaml` changed): in the CloudFormation console, **Create stack →
     With new resources → Upload a template file**, choose the branch's `src/aws/cloudformation.yaml`, and set
     **Plone in a Box release** to the branch name if the script changed too. Delete the stack afterwards.
   * Checks on each test server:
     * right after creating the server, its address shows the setup progress page, which turns into the site
     * `/root/plone-credentials.txt` exists, the site loads, and `admin` can log in with the generated password
     * deploy once more with **Plone admin password** set: `admin` logs in with that password, and the credentials
       file doesn't contain it
     * `sudo plone-reset-admin-password` changes the password, and the new one works
     * from outside, ports 5432, 8080 and 3000 time out (`nc -zv -w 5 <ip> <port>`)
     * after `docker compose --project-directory /opt/plone up -d --force-recreate backend`, the same password
       still works
   * Delete the test servers afterwards (`terraform destroy` with the same `-var` options).
   * Or let `scripts/test-deploy.sh linode --ref <branch>` (or `digitalocean` or `aws`) do the test: it creates a
     server (1 GB on Linode and DigitalOcean, `t3.small` on AWS) with the launcher or StackScript from the branch,
     runs these checks plus a restart, and deletes the server (about 15 minutes). Add
     `--generated-password` for the generated-password check. `scripts/test-deploy.sh cleanup linode` deletes any
     test servers left behind. See [Automated test deploys](#automated-test-deploys) for the one-time setup.
3. Merge the pull request.

### Automated test deploys

One-time setup for `scripts/test-deploy.sh`:

* **SSH key** for test servers only: `ssh-keygen -t ed25519 -f ~/.ssh/piab_test_ed25519 -C piab-test -N ''`
* **Linode**: in the tknguyen2 account, the restricted user `piab-test` (Identity & Access) has only the roles
  `account_linode_creator`, `account_stackscript_creator` and the default viewer roles, so it can create servers
  but can't touch existing Linodes or the public StackScript. As `piab-test`:
  * a private StackScript `plone-in-a-box-test` (Target Images: Ubuntu 24.04); the script overwrites it each run
  * a personal access token (Linodes Read/Write, StackScripts Read/Write, Events Read Only, 1-month expiry),
    stored with `security add-generic-password -a "$USER" -s piab-linode-token -w`
* **DigitalOcean**: a token with custom scopes `droplet` create/read/delete, `ssh_key` create/read and `tag`
  create/read (30-day expiry), stored with `security add-generic-password -a "$USER" -s piab-do-token -w`. The
  first run adds the SSH key to the account as `piab-test`.
* **AWS**: install the AWS CLI (`brew install awscli`). In IAM, create a user `piab-test` with no console access
  and one inline policy, the contents of [`scripts/aws-test-policy.json`](scripts/aws-test-policy.json): it can
  launch, restart and terminate only instances tagged `piab-test`, and create only the `piab-test` key pair and
  security group. Create an access key for it (use case: Command Line Interface) and store both parts:
  `security add-generic-password -a "$USER" -s piab-aws-access-key-id -w` and
  `security add-generic-password -a "$USER" -s piab-aws-secret-access-key -w`. Tests run in `us-east-1` unless
  `PIAB_TEST_REGION` is set; the first run in a region adds the key pair and the security group there.

Tokens stay in the macOS Keychain; never paste them into chats or commit them. Remove one with
`security delete-generic-password -s piab-linode-token` (or `piab-do-token`, or the two AWS entries). Deactivate
the AWS access key in IAM when it's not needed; it doesn't expire by itself.

## 2. Release

1. In `CHANGES.md`, replace `(unreleased)` with today's date. If `src/StackScript` changed, set `PIAB_RELEASE` in
   `src/user-data.sh` and the `Release` parameter's `Default` in `src/aws/cloudformation.yaml` to the new version,
   so pasted launchers and the Launch Stack button download it. Commit to `main` (or include it in the last PR).
2. On GitHub, go to **Releases → Draft a new release**. Create a tag on `main` named after the version, without a
   `v` (for example `2.1`), set the title to `Plone in a Box 2.1`, and summarize the changes.

3. If `src/aws/cloudformation.yaml` changed (including its `Release` default), publish it for the **Launch Stack**
   button, which opens `https://plone-in-a-box-templates.s3.us-east-1.amazonaws.com/latest/cloudformation.yaml`. In
   the AWS console (Plone Foundation account), open **S3 → plone-in-a-box-templates**, and upload
   `src/aws/cloudformation.yaml` from `main` twice: into the folder `latest/`, replacing the file there, and into a
   new folder named after the version (for example `2.6/`), to keep a copy of each release. Then click the button
   in the README and check that the form shows the new version's defaults.

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

## 3. Update the public Linode StackScript

1. Log in to Cloud Manager as **nguyen-plone**, the account that owns the public **Plone in a Box** StackScript.
2. **StackScripts → Account StackScripts → ⋯ → Edit**.
3. Replace the **Script** with
   https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/main/src/StackScript, check that **Target Images**
   includes the Ubuntu release the script supports, and enter a revision note such as `2.1: <summary>`.
4. Save, then confirm the Community StackScripts list shows today's date.

Public StackScripts can't be deleted or made private by their owner; only Linode support can remove one.

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

GitHub releases (with notes) are published only on `tkimnguyen/plone-in-a-box`.

Avoid committing directly to `collective`, so these pull requests stay simple fast-forwards. If someone does
contribute there, bring it into this repo first with `git pull collective main`.

Pushing needs an SSH key added to GitHub (`ssh -T git@github.com` should greet you by name). HTTPS pushes with a
password are rejected.
