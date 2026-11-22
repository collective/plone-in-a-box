# "Try it" buttons for add-ons

An add-on's README can say **Try it in Plone in a Box**: a link that opens a cloud provider's form with everything
filled in, so someone can have a real Plone 6 site with the add-on, and a demo login to share, in about 10 minutes.
They use their own cloud account and pay for the server (a few cents an hour), and delete it when they're done.

This page is for add-on authors. It needs Plone in a Box 2.13 or later, for the demo login; 2.14 or later for its
roles from the frontend image, and for choosing its password.

## What you need first

* **An add-on with a Volto part:** a public frontend image with it built in, whose labels name its backend add-on.
  Plone in a Box can build and publish one for you; see
  [Building your own](../frontend-image/README.md#building-your-own) (or ask for a ready-made one in
  `collective/plone-in-a-box`).
* **A backend-only add-on:** nothing; the buttons fill in the **Backend add-ons** setting with its package name and
  version, for example `collective.easyform==4.2.0`.

Choose the roles the demo login gets: the narrowest ones that show off the add-on, for example **Editor**, or a role
the add-on defines for looking without administering. People who get the demo login can do anything those roles
allow on that site. For an add-on with a frontend image, set them once in the image's `demo_roles`
([Frontend images](../frontend-image/README.md#how-setup-uses-an-image)): every button then gets them without saying
so. Otherwise the demo login is a Site Administrator unless the button sets its roles.

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
   `--demo-roles "Editor"` to set the roles here rather than in the image.
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

The parameters are `FrontendImage`, `Addons`, `DemoUser` and `DemoRoles` (for example `param_DemoRoles=Editor`;
by default, the image's suggestion or Site Administrator). The person still sets the admin password and the server size, then clicks
**Create stack**.

## DigitalOcean and Hetzner

Neither can fill in a startup script from a link, so the button links to a section of your README with these lines,
ready to copy into **Startup scripts** (DigitalOcean) or **Cloud config** (Hetzner):

```
#!/bin/bash
export ADMIN_PASSWORD='CHANGE-ME'
export FRONTEND_IMAGE='ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard'
export DEMO_USER='demo'
curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.14/src/StackScript && bash /root/plone-in-a-box.sh
```

Add `export DEMO_PASSWORD='...'` to choose the demo login's password (at least 12 characters), `export DEMO_ROLES='Editor'` to set the roles here, or `export ADDONS='PKG==1.2.3'` for backend add-ons. The rest of
the steps are in the [setup guide](setup-guide.md#option-c-digitalocean).

## The buttons

Two buttons at the top of a **Try it** section in the add-on's README: AWS's own Launch Stack image, and a matching
badge for Linode (Linode has no official button). Replace the image name and the StackScript number with yours:

```markdown
[![Launch Stack on AWS](https://s3.amazonaws.com/cloudformation-examples/cloudformation-launch-stack.png)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https%3A%2F%2Fplone-in-a-box-templates.s3.us-east-1.amazonaws.com%2Flatest%2Fcloudformation.yaml&stackName=my-addon-demo&param_FrontendImage=<your image, URL-encoded>&param_DemoUser=demo)
[![Deploy on Linode](https://img.shields.io/badge/Deploy%20on-Linode-00a95c?logo=akamai&logoColor=white&style=for-the-badge)](https://cloud.linode.com/stackscripts/<number>)
```

Below them, keep it short:
- what it costs (a few cents an hour on their own account) and that they delete the server when they're done;
- two steps: click a button, fill in an admin password and a **Demo login password**, create the server; then log in
  as `demo` and open the add-on's screen;
- what the demo login can do, given its roles.

Put the rest in a folded `<details>` section: each provider's steps, the DigitalOcean and Hetzner lines (they have no
button), and how to find a generated demo password. [Juizi Dashboard's README](https://github.com/tkimnguyen/juizi.dashboard#try-it)
is a complete example, with the public StackScript [2318969](https://cloud.linode.com/stackscripts/2318969).

## After the server is set up

Whoever creates the server can choose the demo login's password in the form (**Demo login password**, or
`DemoPassword` on AWS, which the link leaves for them to fill in), so they know it without reading a file. Never
put a password in the button's link or StackScript: everyone who clicks it would share it.

The site's address, and the admin and demo passwords, are in `/root/plone-credentials.txt` on the server
(`sudo cat /root/plone-credentials.txt` in the provider's browser console). The demo login is an ordinary Plone
user: change its password or remove it in **Site Setup → Users**. See [Demo login](setup-guide.md#demo-login).
