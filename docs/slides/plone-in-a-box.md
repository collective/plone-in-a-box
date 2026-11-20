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
---

<!-- _class: lead -->
<!-- _paginate: false -->

# Plone in a Box™

Your own Plone 6 website on a cloud server,
without needing a command line.

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
- **nginx** in front, with optional HTTPS from **Let's Encrypt**
- managed with plain **Docker Compose** in `/opt/plone`, so a Plone developer finds nothing unusual

Versions are configurable; Plone 6.1 with Volto 18 also works. Add-ons and themes are optional settings.

---

## Safe by default

- The admin password is **the one you choose**, or a generated one.
- Only the **website** (HTTP, HTTPS) and **SSH** are reachable from the internet. The database and Plone's own ports are closed.
- **All Ubuntu updates** are installed during setup, and security updates keep coming automatically.
- **Swap** is added on small servers, so a 1 GB server is enough for a small site.
- Forgot the password? One command in your provider's **browser console** resets it.

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

Developers can use **Terraform** for AWS, DigitalOcean and Hetzner instead.

---

## Why it's useful

- **Small organizations, teams, projects** get a real Plone site, or an intranet, without hiring an administrator.
- **Evaluating Plone?** See the current release running in ten minutes, for the price of a small server.
- **Training and workshops:** every participant gets their own site.
- **No lock-in:** the official Plone images and standard Docker Compose, so it can be upgraded, backed up and handed over like any other Plone deployment.

---

## Add-ons

List Python packages such as `collective.easyform` when you create the server. Then activate them in **Site Setup → Add-ons**.

- No custom build needed: the official backend image installs them.
- Held to the versions each Plone release was tested with.
- A misspelled name doesn't break anything: setup continues without the add-ons and says why.

---

## Themes: Volto Light Theme

Set the **Frontend image** to `ghcr.io/collective/plone-in-a-box-frontend:19-vlt` when you create the server.

- The site runs **Volto Light Theme**: logo, colours, header and footer, edited with the site's own settings.
- Setup also installs and activates the theme's backend add-on. Nothing to do in Site Setup.
- **Ready-made images**, built from the official Volto image on GitHub and rebuilt every week.
- If the image can't be used, the site starts with the standard Volto look, and says why.

---

## Your own add-ons and themes

- **Volto add-ons:** fork the repository, add the add-ons to one file, and GitHub builds and publishes your own frontend image. Setup installs its backend half too.
- **Packages that aren't on PyPI,** or your own code: build a backend image on the official one, and switch a running server to it.

Next on the list: a **backend image setting**, for projects made with cookieplone.

---

<!-- _class: lead -->

## Get started

**github.com/collective/plone-in-a-box**

The official repository, in the Plone community's **collective** organization. Step-by-step instructions for each provider are in the setup guide.
