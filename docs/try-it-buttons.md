# "Try It" buttons for add-ons

An add-on's README can say **Try It in Plone in a Box**: a button that leads to a page with everything filled in, so
someone can have a real Plone 6 site with the add-on, and a demo login to share, in about 10 minutes. They use their
own cloud account and pay for the server (a few cents an hour), and delete it when they're done.

This page is for add-on authors.

## The easy way: add your add-on to the catalog

1. **Open a pull request** to [`collective/plone-in-a-box`](https://github.com/collective/plone-in-a-box) that adds
   one entry to [`addons.yml`](../addons.yml). For an add-on with a Volto part:

   ```yaml
   - id: my-addon
     name: My Add-on
     description: a short description, finishing "Your own Plone 6 site with My Add-on, ..."
     url: https://github.com/me/my-addon
     volto: 19
     packages: volto-my-addon@1.2.0
     addons: volto-my-addon
     backend_addons: my.addon==1.2.0
     demo_roles: Editor
     try_it: yes
     try_hint: open My Add-on in the toolbar and try it on a page
   ```

   A backend-only add-on needs no image: leave out `volto`, `packages` and `addons`, and setup installs
   `backend_addons` on the site.

   **Ready-made images**, such as a Plone distribution's, which you build and publish yourself: give the images
   instead of `volto`, `packages` and `addons`, and nothing is built here.

   ```yaml
   - id: my-distribution
     name: My Distribution
     description: a short description, as above
     url: https://github.com/me/my-distribution
     frontend_image: ghcr.io/me/my-distribution-frontend:1.2
     backend_image: ghcr.io/me/my-distribution-backend:1.2
     demo_roles: Editor
     try_it: yes
     try_hint: look around the sample pages and edit one
   ```

   The images must be public and built for `linux/amd64`, and the backend image must start like the official
   one ([Custom backend image](setup-guide.md#custom-backend-image) says what that means). Use tags that move with
   your patch releases, such as `1.2`, so the weekly update installs them. Either image can be left out: a
   frontend image alone runs with the official backend, and a backend image alone with the standard Volto.
   If both are built for `linux/arm64` too, add `arm: yes`; otherwise the page tells Hetzner users to choose an x86
   server.

   The comments at the top of `addons.yml` explain every key.
2. **When it's merged**, Plone in a Box builds your add-on's frontend image (`ghcr.io/collective/plone-in-a-box-frontend:19-my-addon`,
   rebuilt every week; not for ready-made images), and publishes its Try It page at
   `https://collective.github.io/plone-in-a-box/try/my-addon/`, with:
   * a Launch Stack link for AWS, with your add-on and the demo login filled in;
   * the Linode steps, and the lines to paste on DigitalOcean and Hetzner, for the current release;
   * what to do after logging in as `demo` (your `try_hint`), what its roles allow, and how to find a forgotten
     password.
3. **Add the button to your README.** The bottom of your Try It page has it, ready to copy:

   ```markdown
   [![Try It in Plone in a Box](https://img.shields.io/badge/Try%20It-Plone%20in%20a%20Box-0083be)](https://collective.github.io/plone-in-a-box/try/my-addon/)
   ```

That's all. The page follows Plone in a Box's releases by itself. To release a new version of your add-on, open
another pull request that changes the versions in your entry.

**Choose the demo login's roles carefully:** the narrowest ones that show off the add-on, for example **Editor**,
or a role your add-on defines for looking without administering. People who get the demo login can do anything those
roles allow on that site. Without `demo_roles`, it's a Site Administrator. Manager isn't allowed.

CI checks each entry (exact versions, allowed roles) and builds the image before anyone merges it, and
`python3 scripts/catalog.py check` does the same on your computer.

**On Linode**, the page links to the main Plone in a Box StackScript and says which values to paste into it, since
Linode can't fill in a form from a link. For one click instead, make a public StackScript for your add-on (see
[Linode](#linode) below), and add `linode_stackscript: <its number>` to your entry.

## Doing it yourself

You can also make the buttons yourself, without the catalog: for example, for an image you build in your own fork
([Building your own](../frontend-image/README.md#building-your-own)), or to put the steps in your README.

### What you need first

* **An add-on with a Volto part:** a public frontend image with it built in, whose labels name its backend add-on.
  Plone in a Box can build and publish one for you; see
  [Building your own](../frontend-image/README.md#building-your-own) (or add it to
  [the catalog](#the-easy-way-add-your-add-on-to-the-catalog)).
* **A backend-only add-on:** nothing; the buttons fill in the **Backend add-ons** setting with its package name and
  version, for example `collective.easyform==4.2.0`.

Choose the roles the demo login gets: the narrowest ones that show off the add-on, for example **Editor**, or a role
the add-on defines for looking without administering. People who get the demo login can do anything those roles
allow on that site. For an add-on with a frontend image, set them once in the image's `demo_roles`
([Frontend images](../frontend-image/README.md#how-setup-uses-an-image)): every button then gets them without saying
so. Otherwise the demo login is a Site Administrator unless the button sets its roles.

### Linode

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
   public StackScripts can't be deleted or made private again, not even by Linode support.
4. The button links to `https://cloud.linode.com/stackscripts/<its number>`; there, **Deploy New Linode** opens the
   form with the add-on filled in.

### Amazon AWS

The Launch Stack link can fill in the template's parameters: add `&param_<Name>=<value>` to it, URL-encoded.

```
https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https%3A%2F%2Fplone-in-a-box-templates.s3.us-east-1.amazonaws.com%2Flatest%2Fcloudformation.yaml&stackName=plone-in-a-box&param_FrontendImage=ghcr.io%2Fcollective%2Fplone-in-a-box-frontend%3A19-juizi-dashboard&param_DemoUser=demo
```

The parameters are `FrontendImage`, `BackendImage`, `Addons`, `DemoUser` and `DemoRoles` (for example `param_DemoRoles=Editor`;
by default, the image's suggestion or Site Administrator). The person still sets the admin password and the server size, then clicks
**Create stack**.

### DigitalOcean and Hetzner

Neither can fill in a startup script from a link, so the button links to a section of your README with these lines,
ready to copy into **Startup scripts** (DigitalOcean) or **Cloud config** (Hetzner):

```
#!/bin/bash
export ADMIN_PASSWORD='CHANGE-ME'
export FRONTEND_IMAGE='ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard'
export DEMO_USER='demo'
curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.23/src/StackScript && bash /root/plone-in-a-box.sh
```

Add `export DEMO_PASSWORD='...'` to choose the demo login's password (at least 12 characters), `export DEMO_ROLES='Editor'` to set the roles here, `export BACKEND_IMAGE='...'` for a backend image, or `export ADDONS='PKG==1.2.3'` for backend add-ons. The rest of
the steps are in the [setup guide](setup-guide.md#option-c-digitalocean).

### The buttons

Two buttons at the top of a **Try It** section in the add-on's README: AWS's own Launch Stack image, and a matching
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

### After the server is set up

Whoever creates the server can choose the demo login's password in the form (**Demo login password**, or
`DemoPassword` on AWS, which the link leaves for them to fill in), so they know it without reading a file. Leave
passwords out of the button's link and StackScript: everyone who clicks it would share them.

The site's address, and the admin and demo passwords, are in `/root/plone-credentials.txt` on the server
(`sudo cat /root/plone-credentials.txt` in the provider's browser console). The demo login is an ordinary Plone
user: change its password or remove it in **Site Setup → Users**. See [Demo login](setup-guide.md#demo-login).
