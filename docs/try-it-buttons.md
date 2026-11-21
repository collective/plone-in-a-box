# "Try it" buttons for add-ons

An add-on's README can say **Try it in Plone in a Box**: a link that opens a cloud provider's form with everything
filled in, so someone can have a real Plone 6 site with the add-on, and a demo login to share, in about 10 minutes.
They use their own cloud account and pay for the server (a few cents an hour), and delete it when they're done.

This page is for add-on authors. It needs Plone in a Box 2.13 or later, for the demo login.

## What you need first

* **An add-on with a Volto part:** a public frontend image with it built in, whose labels name its backend add-on.
  Plone in a Box can build and publish one for you; see
  [Building your own](../frontend-image/README.md#building-your-own) (or ask for a ready-made one in
  `collective/plone-in-a-box`).
* **A backend-only add-on:** nothing; the buttons fill in the **Backend add-ons** setting with its package name and
  version, for example `collective.easyform==4.2.0`.

Choose the role the demo login gets (**Site Administrator**, **Editor**, **Contributor**, **Reviewer** or
**Member**): the narrowest one that shows off the add-on. People who get the demo login can do anything that role
allows on that site.

## Linode

Linode's Cloud Manager can't fill in a StackScript's fields from a link, so each add-on gets its own small public
StackScript, with the add-on's settings as the form's defaults. It downloads the latest Plone in a Box release
when a server is created, so it doesn't need updating at each release.

1. Print the StackScript:

   ```
   scripts/linode-addon-stackscript.sh --name "Juizi Dashboard" \
     --frontend-image ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard \
     > juizi-dashboard.stackscript
   ```

   Use `--addons "PKG==1.2.3"` instead of (or as well as) `--frontend-image` for backend add-ons, and
   `--demo-role Editor` for another role than Site Administrator.
2. In [Cloud Manager](https://cloud.linode.com), **StackScripts → Create StackScript**: label it
   `Plone in a Box: Juizi Dashboard`, choose **Ubuntu 26.04 LTS** and **Ubuntu 24.04 LTS** as Target Images, paste
   the script, and save.
3. Deploy a Linode from it once, to check it works. Then **⋯ → Make StackScript Public**. **This can't be undone:**
   public StackScripts can't be deleted or made private again, only removed by Linode support.
4. The button links to `https://cloud.linode.com/stackscripts/<its number>`; there, **Deploy New Linode** opens the
   form with the add-on filled in.

## Amazon AWS

The Launch Stack link can fill in the template's parameters: add `&param_<Name>=<value>` to it, URL-encoded.

```
https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https%3A%2F%2Fplone-in-a-box-templates.s3.us-east-1.amazonaws.com%2Flatest%2Fcloudformation.yaml&stackName=plone-in-a-box&param_FrontendImage=ghcr.io%2Fcollective%2Fplone-in-a-box-frontend%3A19-juizi-dashboard&param_DemoUser=demo
```

The parameters are `FrontendImage`, `Addons`, `DemoUser` and `DemoRole` (for example `param_DemoRole=Editor`;
Site Administrator is the default). The person still sets the admin password and the server size, then clicks
**Create stack**.

## DigitalOcean and Hetzner

Neither can fill in a startup script from a link, so the button links to a section of your README with these lines,
ready to copy into **Startup scripts** (DigitalOcean) or **Cloud config** (Hetzner):

```
#!/bin/bash
export ADMIN_PASSWORD='CHANGE-ME'
export FRONTEND_IMAGE='ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard'
export DEMO_USER='demo'
curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.12/src/StackScript && bash /root/plone-in-a-box.sh
```

Add `export DEMO_ROLE='Editor'` for another role, or `export ADDONS='PKG==1.2.3'` for backend add-ons. The rest of
the steps are in the [setup guide](setup-guide.md#option-c-digitalocean).

## The button

A badge in the add-on's README, linking to the Linode StackScript (or a section listing all three):

```markdown
[![Try it in Plone in a Box](https://img.shields.io/badge/Try%20it-Plone%20in%20a%20Box-0083be)](https://cloud.linode.com/stackscripts/<number>)
```

Say what it costs and that the person deletes the server when they're done, and link to
[Get started](../README.md#get-started) for choosing a provider.

## After the server is set up

The site's address, and the admin and demo passwords, are in `/root/plone-credentials.txt` on the server
(`sudo cat /root/plone-credentials.txt` in the provider's browser console). The demo login is an ordinary Plone
user: change its password or remove it in **Site Setup → Users**. See [Demo login](setup-guide.md#demo-login).
