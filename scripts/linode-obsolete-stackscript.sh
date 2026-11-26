#!/bin/bash
#
# OBSOLETE: this copy of the Plone in a Box StackScript is no longer maintained.
# Use the Plone in a Box StackScript 931893 by nguyen-plone instead:
# https://cloud.linode.com/stackscripts/931893
#
# Linode doesn't remove public StackScripts, so this one stays. It sets up your server with the latest Plone in a Box
# release, exactly as 931893 does: it downloads that release's provisioning
# script and runs it with the settings from this form.
#
# <UDF name="ADMIN_PASSWORD" label="Plone admin password, at least 12 characters. Leave empty to have one generated and saved on the server" default="" />
# <UDF name="DOMAIN" label="Domain name for the site, optional. DNS must already point here to get HTTPS" default="" />
# <UDF name="LETSENCRYPT_EMAIL" label="Email for Lets Encrypt certificate notices, required if a domain is set" default="" />
# <UDF name="SITE_TIMEZONE" label="Site time zone" default="UTC" example="America/Chicago" />
# <UDF name="SITE_LANGUAGE" label="Site language: a language code such as en, de, fr, es or pt-br" default="en" example="de" />
# <UDF name="STARTER_CONTENT" label="Starter content: yes creates the sample pages a new site or Plone distribution comes with; no starts with an empty site" oneOf="yes,no" default="yes" />
# <UDF name="PLONE_VERSION" label="Plone backend image tag" default="6.2" />
# <UDF name="VOLTO_VERSION" label="Volto frontend image tag" default="19" />
# <UDF name="ADDONS" label="Backend add-ons, optional: Python package names separated by spaces, for example collective.easyform. Activate them afterwards in Site Setup, Add-ons" default="" />
# <UDF name="FRONTEND_IMAGE" label="Frontend image, optional: a ready-made Plone in a Box image such as ghcr.io/collective/plone-in-a-box-frontend:19-vlt (Volto Light Theme), or your own. Empty: the standard Volto image" default="" />
# <UDF name="BACKEND_IMAGE" label="Backend image, optional: replaces the official Plone backend, for example a Plone distribution such as ghcr.io/kitconcept/kitconcept-intranet-backend:3.11 (with its frontend image above), or your own project's. Empty: the official Plone backend" default="" />
# <UDF name="REGISTRY_USER" label="Registry login for private images, optional: the username for the registry of the frontend and backend images above, for example your GitHub username for ghcr.io" default="" />
# <UDF name="REGISTRY_TOKEN" label="Registry token: a read-only access token for that registry, such as a GitHub token with only read:packages" default="" />
# <UDF name="DEMO_USER" label="Demo login, optional: a username such as demo, for people you let try the site. Setup creates it with a generated password, saved next to the admin password" default="" />
# <UDF name="DEMO_PASSWORD" label="Demo login password, optional, at least 12 characters. Leave empty to have one generated and saved next to the admin password" default="" />
# <UDF name="DEMO_ROLES" label="Roles of the demo login, optional, separated by commas, for example Editor or Site Administrator. Empty: what the frontend image suggests, or Site Administrator" default="" />
# <UDF name="AUTO_UPDATE" label="Automatic updates: install Plone, Volto and PostgreSQL patch releases every week, after a database backup, and undo them if the site doesn't come back" oneOf="yes,no" default="yes" />
# <UDF name="NOTIFY_URL" label="Notification URL, optional: update reports go here, for example https://ntfy.sh/your-own-topic, or a Slack, Discord, Google Chat, Mattermost or Microsoft Teams webhook" default="" />
# <UDF name="SMTP_HOST" label="Email: SMTP server of an email relay service, optional, for example mail.smtp2go.com. Empty: the site doesn't send email" default="" />
# <UDF name="SMTP_PORT" label="Email: SMTP port" default="587" />
# <UDF name="SMTP_USER" label="Email: SMTP username" default="" />
# <UDF name="SMTP_PASSWORD" label="Email: SMTP password" default="" />
# <UDF name="EMAIL_FROM" label="Email: the site's From address, at a domain the email service has verified, for example plone@example.org" default="" />
# <UDF name="REPORT_EMAIL" label="Email: your address for a test email and the update reports. Empty: the From address" default="" />
# <UDF name="SPAMHAUS_KEY" label="Spamhaus DQS key, optional: a free key from spamhaus.com, so the blocklist checks can ask Spamhaus from any cloud provider" default="" />

NOTICE="This server was created with an obsolete copy of the Plone in a Box StackScript (692002). Next time, use StackScript 931893: https://cloud.linode.com/stackscripts/931893"
echo "[plone-in-a-box] $NOTICE" >> /var/log/plone-in-a-box.log
printf '\n%s\n\n' "$NOTICE" > /etc/motd

# The latest release, or this one if GitHub can't be asked.
PIAB_RELEASE=$(curl -fsS -m 20 https://api.github.com/repos/tkimnguyen/plone-in-a-box/releases/latest 2>/dev/null \
  | sed -n 's/^  "tag_name": "\([0-9][0-9.]*\)",$/\1/p')
PIAB_RELEASE=${PIAB_RELEASE:-2.25}
SCRIPT_URL="https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/${PIAB_RELEASE}/src/StackScript"

export ADMIN_PASSWORD DOMAIN LETSENCRYPT_EMAIL SITE_TIMEZONE SITE_LANGUAGE STARTER_CONTENT PLONE_VERSION VOLTO_VERSION ADDONS FRONTEND_IMAGE BACKEND_IMAGE REGISTRY_USER REGISTRY_TOKEN AUTO_UPDATE NOTIFY_URL DEMO_USER DEMO_PASSWORD DEMO_ROLES SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASSWORD EMAIL_FROM REPORT_EMAIL SPAMHAUS_KEY
set -uo pipefail
SCRIPT=$(mktemp)
if ! curl --fail --silent --show-error --location --retry 10 --retry-delay 5 --retry-all-errors \
    --output "$SCRIPT" "$SCRIPT_URL"; then
  echo "[plone-in-a-box] Could not download $SCRIPT_URL" | tee -a /var/log/plone-in-a-box.log >&2
  exit 1
fi
exec bash "$SCRIPT"
