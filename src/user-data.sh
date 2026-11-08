#!/bin/bash

# =============================================================================
#  SET THE PLONE ADMIN PASSWORD HERE (at least 12 characters), between the
#  single quotes. It can't contain a single quote itself.
# =============================================================================
export ADMIN_PASSWORD=''
# If you leave it empty, a password is generated. To read it later, open the
# server's browser console and run:
#   sudo cat /root/plone-credentials.txt
# (or set a new one with: sudo plone-reset-admin-password)
#   DigitalOcean: the Droplet's Access > Launch Droplet Console
#   AWS: the instance's Connect > EC2 Instance Connect (user "ubuntu")

#
# Plone in a Box(TM) without Terraform, for DigitalOcean and Amazon AWS.
#
# Create an Ubuntu 24.04 server, paste this whole file into its user data box,
# and edit the settings in it. Keep each value inside its single quotes.
#   DigitalOcean: Create > Droplets > Additional Options > "Startup scripts
#     (free)" > "Enter your scripts or data".
#   AWS: EC2 > Launch instance > Advanced details > "User data". In Network
#     settings, also allow HTTP and HTTPS traffic from the internet.
#
# Open the server's address a minute or two after it boots to watch the setup
# progress page, which turns into your Plone site when it's ready (about
# 10 minutes). Log in as "admin".

# Domain name for the site, optional. DNS must already point at the server
# to get HTTPS, and LETSENCRYPT_EMAIL is required with it.
export DOMAIN=''
export LETSENCRYPT_EMAIL=''

# Site time zone, for example America/Chicago.
export SITE_TIMEZONE='UTC'

# Plone backend and Volto frontend image tags.
export PLONE_VERSION='6.2'
export VOLTO_VERSION='19'

# --- No need to edit below this line -----------------------------------------

# The Plone in a Box release whose provisioning script is downloaded and run.
PIAB_RELEASE='2.5'
SCRIPT_URL="https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/${PIAB_RELEASE}/src/StackScript"

set -uo pipefail
SCRIPT=$(mktemp)
if ! curl --fail --silent --show-error --location --retry 10 --retry-delay 5 --retry-all-errors \
    --output "$SCRIPT" "$SCRIPT_URL"; then
  echo "[plone-in-a-box] Could not download $SCRIPT_URL" | tee -a /var/log/plone-in-a-box.log >&2
  exit 1
fi
exec bash "$SCRIPT"
