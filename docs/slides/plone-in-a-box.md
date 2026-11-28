---
marp: true
theme: default
paginate: true
title: Plone in a Box™
description: Your own Plone 6 website on a cloud server, easily installed without a command line
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
easily installed without a command line.

<small>Release 2.26 · November 2026</small>

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
<div><b>2. Choose a password</b>For the site's <code>admin</code> account.</div>
<div><b>3. Click Create</b>About 10 minutes later, the server's address shows your new Plone site.</div>
</div>

<br>

**That's it. Everything else is optional, and can be added once your site is running.**

Nothing to install on your computer. While you wait, the address shows a page with the setup progress, and it turns into your site when it's ready.

---

## What's in the box

One Ubuntu 26.04 LTS server, running the **official Plone Docker images**:

- **Plone 6.2** backend, **Volto 19** front end, **PostgreSQL** for storage
- **nginx** in front, with HTTPS from **Let's Encrypt**
- best practices for application and server setup and maintenance
- standard deployment tooling, easily extendable and customizable by a Plone developer 

Optional: choose the site's language, Plone & Volto versions, add-ons, themes and whether to start with Plone's welcome page. A **Plone distribution**, such as kitconcept's intranet, can replace the standard site.

---

<!-- _class: dense -->

## Safe by default

- Choose your own admin password or generate a safe one.
- Immediately secure browsing using **HTTPS for every site**, automatically renewed.
- Multiple firewalls secure your site and server.
- Secure **SSH key access**, and automatic blocking of failed login attempts.
- **Security headers** served on every page.
- **All Ubuntu OS updates** are installed during setup and automatically afterwards, including overnight server restarts as needed.
- **Plone security fixes** automatically installed the day they come out.
- Forgot the admin password? Reset it with one command in your cloud provider's browser console.

---

<!-- _class: dense -->

## Updates that look after themselves

Every early Sunday morning, the server checks for patch releases of Plone and Volto, e.g., Plone 6.2.2 to 6.2.3. (Moving to new major or minor versions, such as 6.3 or 7.0, is up to you).

- First a **database backup**, then the update.
- If there is a problem, **automatic fallback** to the previous version, and skips that failed version from then on.
- A **report** after each run: pushed to your phone (ntfy), in a team chat (Slack, Teams, Discord, Google Chat, Mattermost), or by email.
- **Security fixes the same day:** when the Plone forum announces a released fix, the server installs it that day. Each Plone security announcement is sent to you the same ways.

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

Developers can instead use the **Terraform plan** for AWS, DigitalOcean and Hetzner.

---

<!-- _class: dense -->

## Choose your path

Start with the three steps, then add only what your site needs:

- **Just trying Plone:** nothing more; a welcome page shows you where to start.
- **Your organization's site:** your domain name, email & notifications, then offsite backups.
- **An intranet:** kitconcept's intranet, ready to use.
- **Letting others try it:** a demo login, with the roles you choose.
- **Training or a workshop:** a server per person, or Terraform for many at once.
- **Showing off your add-on:** a Try It page.

**No need to decide everything now:** all of it can be added once your site is running.

---

## Who this is for

- **Evaluating Plone in depth?** Get the current release running in ten minutes, on your own server.
- **Small organizations, teams, projects** get a well set up Plone site, or an intranet, without hiring an administrator.
- **Training and workshops:** every participant gets their own site.
- **Showing a site to a client,** or letting people try an add-on.
- **No lock-in:** the official Plone images and standard Docker Compose, so it can be upgraded, backed up and handed over like any other Plone deployment.

---

<!-- _class: dense -->

## Backups

- A database backup **every night,** on the server: the whole site, files and images included. The three newest are kept.
- A database pack **every week**: the database's old history is cleared, so it doesn't keep growing.
- Easy restore from backup, using one command **`sudo plone-restore`**, with automatic fallback. Use it to **move a site** to a new server.
- **Encrypted offsite backups:** each night's backup can also go to Cloudflare R2, AWS S3, Backblaze B2 or other storage, encrypted first on the server.
- **Once a month, a restore test:** the newest backup (on server or offsite) is restored into a test database and verified, without affecting your site.
- Optional cloud provider's **server backups** for the entire server.

---

<!-- _class: dense -->

## Comprehensive monitoring

- **Stay in the loop:** receive notifications of errors (failed backup, update or restore test, disk getting full) via email and/or other channels.
- **External checks:** get notified when the site is down and, on DigitalOcean, alerts for disk, memory and CPU spikes.
- **View server logs centrally:** `plone-syslog` sends the server's logs to Better Stack's free plan, Papertrail or your own log server.
- **See how your site is doing over time:** `plone-otel` sends graphs of your server and site (memory, disk, response times, errors) to Grafana Cloud's free plan or another OpenTelemetry service, with a ready-made dashboard. Thanks to Jean Jordaan for the idea!
- **From the start:** turn on logs & graphs in the launch form.
- **Secured by Cloudflare:** optional `plone-cloudflare` lets only Cloudflare reach the site and helps block bots and DDOS attacks.

---

<!-- _class: dense -->

## Your site at a glance: the control panel

- **How your site is doing, in plain words,** on your phone or computer: the site, its parts, disk, memory, the last backup and restore test, updates, and what's turned on.
- **Buttons for the everyday things:** back up now, run the restore test, send a test notification or email, a new demo password after a workshop. You see when each one is done.
- **Works when Plone doesn't:** it's separate from the site, so it's there when you need it most.
- **Safe by design:** its own login, failed logins blocked, and it can do only what its buttons do. No extra software: it's built on what the server already has.
- **Tick Control panel** when you create the server, or turn it on later with `sudo plone-panel on`. A preview in 2.27.

---

## Add-ons

**Automatically install Plone add-ons** when you create the server.

- Tested package version pins are matched to your chosen Plone release.
- If an add-on can't be installed, you're told why and setup carries on.

---

<!-- _class: dense -->

## Ready-made Volto images

Volto add-ons are built into the front end, so Plone in a Box publishes **ready-made frontend images**. Choose a **frontend image** when you create the server:

- standard Volto
- `ghcr.io/collective/plone-in-a-box-frontend:19-vlt`: **Volto Light Theme**, its logo, colours, header and footer configured using the site's control panels.
- `ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard`: **Juizi Dashboard**, a record of who did what on the site.

Images are rebuilt every week; if one can't be used, the site starts with standard Volto, and tells you why.

---

<!-- _class: dense -->

## Email

Plone sends email for password resets, forms and update reports. Your site can send email through an **email relay service**: SMTP2GO, Brevo, Mailgun, Amazon SES and others, many with a free plan.

- Set up an email relay service account
- **Fill out some fields** when you create your site.
- Your site sends you a **test email**.
- Your server's weekly update reports and any warning/error reports go to your inbox too.
- Receive a weekly report if your domain or the site's internet address are found in **spam blocklists**.

See the included setup guide to compare email relay services.

---

<!-- _class: dense -->

## Let people try your site

A **demo login**: a second login, such as `demo`, for a client looking at a draft site, or someone trying an add-on.

- **You choose its roles:** Editor, Contributor, Reviewer, Site Administrator, or a role an add-on defines.
- **You choose its password,** or setup generates one.

Change it or remove it any time in **Site Setup → Users**.

---

<!-- _class: dense -->

## Try It pages for add-on authors

Use Plone in a Box to make it easy for someone to try your Plone add-on or distribution on a real site of their own.

1. **One pull request** adds your add-on to Plone in a Box's catalog (npm and Python packages and the demo login's roles).
2. If needed, Plone in a Box builds the frontend image, then publishes a **Try It page**, with the steps for deploying to AWS, Linode, DigitalOcean and Hetzner.
3. **One button** in your README links to it.

Examples: **…/try/juizi-dashboard/** and **…/try/aurora/**, Plone's future frontend.

---

## What's next

- **A control panel for Plone in a Box™:** turn features on and off and change their settings, without SSH.
- **MCP:** ask an AI assistant "is my site healthy?" or "when was the last backup?", and have it answer from your server.
- **Plone distributions to try:** kitconcept's intranet and website, and PortalBrasil.
- **More add-ons** in the catalog, each with its own Try It page.

---

<!-- _class: lead -->

## Get started

Plone's easy button:

**collective.github.io/plone-in-a-box**

Plone in a Box™: automatic for the people!

The code: **github.com/collective/plone-in-a-box**

Questions and ideas: **#plone-in-a-box** on the Plone Discord, **discord.gg/jRrsnYkNvS**
