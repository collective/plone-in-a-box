# Releasing Plone in a Box™

`tkimnguyen/plone-in-a-box` is where development happens. `collective/plone-in-a-box` is kept in sync after each
release, and the public Linode StackScript is updated by hand.

## 1. Make and test the changes

1. Work on a branch and open a pull request into `main`. CI (ShellCheck, `terraform fmt`, `terraform validate`)
   must pass.
2. Test the changed script before merging:
   * **Linode**: paste `src/StackScript` from the branch into the private test StackScript (`plone-in-a-box-test`,
     Target Image Ubuntu 24.04) and deploy a 1 GB Linode (Nanode) from it, the smallest size the docs recommend.
   * **AWS** (if `src/aws/` or the script changed): `terraform apply` from `src/aws/` on the branch.
   * **DigitalOcean** (if `src/digitalocean/` or the script changed): `terraform apply` from `src/digitalocean/`.
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
3. Merge the pull request.

## 2. Release

1. In `CHANGES.md`, replace `(unreleased)` with today's date. If `src/StackScript` changed, set `PIAB_RELEASE` in
   `src/user-data.sh` to the new version, so pasted DigitalOcean and AWS launchers download it. Commit to
   `main` (or include it in the last PR).
2. On GitHub, go to **Releases → Draft a new release**. Create a tag on `main` named after the version, without a
   `v` (for example `2.1`), set the title to `Plone in a Box 2.1`, and summarize the changes.

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
