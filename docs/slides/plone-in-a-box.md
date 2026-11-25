---
marp: true
theme: default
paginate: true
title: Plone in a Box™
description: Your own Plone 6 website on a cloud server, without needing a command line
style: |
  :root {
    --blue: #0083be;
    --ink: #1f2933;
    --muted: #52606d;
  }
  section {
    font-family: "Helvetica Neue", Arial, sans-serif;
    color: var(--ink);
    padding: 64px 80px;
  }
  h1, h2 { color: var(--blue); }
  h2 { font-size: 1.6em; margin-bottom: 0.4em; }
  strong { color: var(--ink); }
  section.lead { justify-content: center; }
  section.lead h1 { font-size: 2.4em; margin-bottom: 0.2em; }
  section.lead p { font-size: 1.15em; color: var(--muted); }
  table { font-size: 0.7em; }
  .steps { display: flex; gap: 24px; margin-top: 1em; }
  .steps div { flex: 1; border-top: 6px solid var(--blue); padding-top: 12px; font-size: 0.85em; }
  .steps b { display: block; font-size: 1.3em; color: var(--blue); }
  footer { color: var(--muted); }
  section.dense { font-size: 25px; }
  section.dense code { font-size: 0.85em; }
---

<!-- _class: lead -->
<!-- _paginate: false -->

# Plone in a Box™

Your own Plone 6 website on a cloud server,
without needing a command line.

<small>Release 2.22 · November 2026</small>

---

## The problem

Plone is a mature, secure content management system. But running it yourself means:

- renting and setting up a Linux server
- Docker, a database, a web server in front
- passwords, firewalls, HTTPS certificates
- keeping it all updated

That's a system administrator's job. **Most people who want a Plone site aren't system administrators.**

---

## The idea

<div class="steps">
<div><b>1. Fill in a form</b>On your cloud provider's website: Linode, DigitalOcean, AWS or Hetzner.</div>
<div><b>2. Choose a password</b>For the site's <code>admin</code> account. Everything else, such as a domain name, add-ons or a theme, is optional.</div>
<div><b>3. Click Create</b>About 10 minutes later, the server's address shows your new Plone site.</div>
</div>

<br>

Nothing to install on your computer. While you wait, the address shows a page with the setup progress, and it turns into your site when it's ready.

---

## What's in the box

One Ubuntu 26.04 LTS server, running the **official Plone Docker images**:

- **Plone 6.2** backend, **Volto 19** front end, **PostgreSQL** for storage
- **nginx** in front, with HTTPS from **Let's Encrypt**
- managed with plain **Docker Compose** in `/opt/plone`, so a Plone developer finds nothing unusual

The site's **language**, versions, add-ons, themes and sample pages are settings. A **Plone distribution**, such as kitconcept's intranet, can replace the standard site.

---

<!-- _class: dense -->

## Safe by default

- The admin password is **the one you choose**, or a generated one.
- **HTTPS for every site,** also without a domain name: a certificate for the server's IP address, renewed by itself.
- Only the **website** (HTTP, HTTPS) and **SSH** are reachable from the internet. The database and Plone's own ports are closed.
- **Security headers** on every page, and nginx doesn't reveal its version.
- **All Ubuntu updates** are installed during setup, and security updates keep coming automatically.
- **Plone security fixes** install the same day they come out, and you hear about them, often a week ahead.
- Servers made with **Terraform** or AWS's **Launch Stack** can't be deleted or rebuilt by mistake.
- Forgot the password? One command in your provider's **browser console** resets it.

---

<!-- _class: dense -->

## Updates that look after themselves

Every Sunday, early in the morning, the server checks for patch releases of the **same** versions: Plone 6.2.2 to 6.2.3. Moving to 6.3 is up to you.

- First a **database backup**, then the update.
- If the site doesn't come back, it **goes back** to the previous version, and skips that build from then on.
- A **report** after each run: on your phone (ntfy), in a team chat (Slack, Teams, Discord, Google Chat, Mattermost), or by email.
- **Security fixes the same day:** when the Plone forum announces a released fix, the server installs it that day, not on Sunday, and says so. Each security post is sent the same ways, and shown when you log in.

Older servers get all this with one command.

---

## Pick a provider

| | Linode | DigitalOcean | AWS | Hetzner |
|---|---|---|---|---|
| **Setup** | A form, nothing to paste | Paste a 3-line launcher | Launch Stack button, a form | Paste a 3-line launcher |
| **Smallest server** | 1 GB | 1 GB | `t3.small` (2 GB) | 1 GB |
| **Cost** | Among the lowest | About the same | Noticeably higher | About the same |

**New to all of them?** Choose Linode.
**Already have an account somewhere?** Use that one.
**Prefer a European provider?** Hetzner.

Developers can use **Terraform** for AWS, DigitalOcean and Hetzner instead. It picks a region that offers the server size, and never deletes an existing server.

---

## Why it's useful

- **Small organizations, teams, projects** get a real Plone site, or an intranet, without hiring an administrator.
- **Evaluating Plone?** See the current release running in ten minutes, for the price of a small server.
- **Training and workshops:** every participant gets their own site.
- **Showing a site to a client,** or letting people try an add-on: a demo login to share.
- **No lock-in:** the official Plone images and standard Docker Compose, so it can be upgraded, backed up and handed over like any other Plone deployment.

---

<!-- _class: dense -->

## Backups

- **Every night,** a database backup on the server: the whole site, files and images included. The three newest are kept.
- **Every week,** a pack: the database's old history is cleared, so it doesn't keep growing.
- **`sudo plone-restore`** puts a backup back, after saving the site as it is. If the restore fails, the site goes back as it was. It also **moves a site** to a new server.
- **Encrypted copies off the server:** each night's backup can also go to Cloudflare R2, AWS S3, Backblaze B2 or other storage, encrypted on the server first.
- Your provider's **server backups** can be turned on too, for the whole disk.

---

## Add-ons

List Python packages such as `collective.easyform` when you create the server. Then activate them in **Site Setup → Add-ons**.

- No custom build needed: the official backend image installs them.
- Held to the versions each Plone release was tested with.
- A misspelled name doesn't break anything: setup continues without the add-ons and says why.

---

<!-- _class: dense -->

## Themes and ready-made images

Volto add-ons are built into the front end, so Plone in a Box publishes **ready-made frontend images**. Set one as the **Frontend image** when you create the server:

- `ghcr.io/collective/plone-in-a-box-frontend:19-vlt`: **Volto Light Theme**, its logo, colours, header and footer edited with the site's own settings.
- `ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard`: **Juizi Dashboard**, a record of what happened on the site.

Setup installs and activates the backend half too. Images are rebuilt every week; if one can't be used, the site starts with the standard Volto look, and says why.

---

<!-- _class: dense -->

## Email

Plone sends email for password resets, forms and update reports. Cloud servers can't deliver it themselves, so the site sends it through an **email relay service**: SMTP2GO, Brevo, Mailgun, Amazon SES and others, many with a free plan.

- Fill in the service's settings **when you create the server**.
- Setup puts them into **Site Setup → Mail**, and sends you a **test email**.
- The weekly update reports go to your inbox too.

The setup guide compares the services, and explains the DNS records your domain needs.

---

<!-- _class: dense -->

## Let people try your site

A **demo login**: a second login, such as `demo`, for a client looking at a draft site, or people trying an add-on.

- **You choose its roles:** Editor, Contributor, Reviewer, Site Administrator, or a role an add-on defines (Manager isn't offered).
- **You choose its password,** or setup generates one.
- A ready-made image can suggest the roles: Juizi Dashboard's demo login is an **Editor** who can also see the dashboard.

Change it or remove it any time in **Site Setup → Users**.

---

<!-- _class: dense -->

## Try It pages for add-on authors

Let people try your Plone add-on on a real site of their own, in about ten minutes, without installing anything.

1. **One pull request** adds your add-on to Plone in a Box's catalog: its npm and Python packages, and the demo login's roles.
2. Plone in a Box builds its image and publishes a **Try It page**, with the steps for AWS, Linode, DigitalOcean and Hetzner.
3. **One button** in your README links to it.

Already publish your own images, for a Plone distribution, say? The entry names them, and nothing is built.

Examples: **…/try/juizi-dashboard/** and **…/try/aurora/**, Plone's new frontend

---

## Your own add-ons and themes

- **Volto add-ons:** fork the repository, add an entry to `addons.yml`, and GitHub builds and publishes your own frontend image. Setup installs its backend half too.
- **Backend image:** a Plone distribution, a cookieplone project, or the official image with packages that aren't on PyPI. Setup checks it runs Plone and can create the site, and otherwise uses the official one.

---

## What's next

- **Plone distributions to try:** kitconcept's intranet and website, and PortalBrasil.
- **Aurora** kept up with its releases, and on Arm servers too.
- **More add-ons** in the catalog, each with its own Try It page.

---

<!-- _class: lead -->

## Get started

**github.com/collective/plone-in-a-box**

The official repository, in the Plone community's **collective** organization. Step-by-step instructions for each provider are in the setup guide.

Questions and ideas: **#plone-in-a-box** on the Plone Discord, **discord.gg/jRrsnYkNvS**
