#!/usr/bin/env bash
#
# Print a Linode StackScript for trying one add-on: the Plone in a Box form with
# the add-on's frontend image (or backend add-ons) and a demo login already
# filled in. Paste it into a new StackScript in Cloud Manager, make it public,
# and its link is the add-on's "Try it" button for Linode (Cloud Manager can't
# prefill a StackScript's fields from a link, so each add-on gets its own).
#
# Usage:
#   scripts/linode-addon-stackscript.sh --name "Juizi Dashboard" \
#     --frontend-image ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard \
#     [--addons "PKG ..."] [--demo-user demo] [--demo-role "Site Administrator"] \
#     [--ref REF] > juizi-dashboard.stackscript
#
# Options:
#   --name NAME            the add-on's name, shown in the script's comments
#   --frontend-image IMAGE the frontend image to fill in
#   --addons "PKG ..."     backend add-ons to fill in (for add-ons without a
#                          frontend part); at least one of these two is needed
#   --demo-user NAME       the demo login to fill in (default: demo)
#   --demo-role ROLE       its role (default: Site Administrator)
#   --ref REF              download src/StackScript from this branch, tag or
#                          commit instead of the latest release: for testing
#                          only, e.g. with scripts/test-deploy.sh --linode-script
#
# The printed script downloads the latest Plone in a Box release when a server
# is created, so it doesn't need updating at each release. Its form fields are
# copied from this checkout's src/StackScript; if a release adds a field, print
# the script again and paste it over the old one.

set -euo pipefail

usage() { sed -n '3,29p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
die() { echo "error: $*" >&2; exit 1; }

NAME="" FRONTEND_IMAGE="" ADDONS="" DEMO_USER=demo DEMO_ROLE="Site Administrator" REF=""
while (( $# )); do
  case "$1" in
    --name) NAME=${2:?--name needs a value}; shift ;;
    --frontend-image) FRONTEND_IMAGE=${2:?--frontend-image needs a value}; shift ;;
    --addons) ADDONS=${2:?--addons needs a value}; shift ;;
    --demo-user) DEMO_USER=${2:?--demo-user needs a value}; shift ;;
    --demo-role) DEMO_ROLE=${2:?--demo-role needs a value}; shift ;;
    --ref) REF=${2:?--ref needs a value}; shift ;;
    *) usage ;;
  esac
  shift
done
[[ -n "$NAME" ]] || usage
[[ -n "$FRONTEND_IMAGE$ADDONS" ]] || die "give --frontend-image, --addons or both"
# What goes into the UDF defaults and the script: no quotes or other characters
# the form or the shell would misread.
[[ "$NAME" =~ ^[A-Za-z0-9\ ._()+-]+$ ]] || die "--name: letters, digits, spaces and . _ ( ) + - only"
[[ "$FRONTEND_IMAGE" =~ ^[a-z0-9./:@_-]*$ ]] || die "--frontend-image: not an image name"
[[ "$ADDONS" =~ ^[A-Za-z0-9\ ._,~=!\<\>*+-]*$ ]] || die "--addons: Python package names separated by spaces"
[[ -z "$DEMO_USER" || "$DEMO_USER" =~ ^[a-z][a-z0-9._-]{1,31}$ ]] || die "--demo-user: lowercase letters, digits, . _ -"
case "$DEMO_ROLE" in "Site Administrator"|Editor|Contributor|Reviewer|Member) ;; *) die "--demo-role: not one of the roles offered" ;; esac
[[ "$REF" =~ ^[A-Za-z0-9._/-]*$ ]] || die "--ref: not a branch, tag or commit"

here=$(cd "$(dirname "$0")/.." && pwd)
stackscript="$here/src/StackScript"
fallback=$(sed -n "s/^PIAB_RELEASE='\(.*\)'$/\1/p" "$here/src/user-data.sh")
[[ -n "$fallback" ]] || die "couldn't read PIAB_RELEASE from src/user-data.sh"

# The form fields of src/StackScript, with this add-on's defaults.
set_default() {  # set_default NAME VALUE: on stdin, the UDF lines
  sed -E "s|^(# <UDF name=\"$1\" .*default=\")[^\"]*(\".*)$|\1$2\2|"
}
udfs=$(grep '^# <UDF ' "$stackscript" \
  | set_default FRONTEND_IMAGE "$FRONTEND_IMAGE" \
  | set_default ADDONS "$ADDONS" \
  | set_default DEMO_USER "$DEMO_USER" \
  | set_default DEMO_ROLE "$DEMO_ROLE")
names=$(sed -n 's/^# <UDF name="\([A-Z_]*\)".*/\1/p' <<<"$udfs" | tr '\n' ' ')
for field in FRONTEND_IMAGE ADDONS DEMO_USER DEMO_ROLE; do
  [[ " $names" == *" $field "* ]] || die "src/StackScript has no $field field"
done

if [[ -n "$REF" ]]; then
  release_lines="PIAB_RELEASE='$REF'"
else
  release_lines="# The latest release, or $fallback if GitHub can't be asked.
PIAB_RELEASE=\$(curl -fsS -m 20 https://api.github.com/repos/tkimnguyen/plone-in-a-box/releases/latest 2>/dev/null \\
  | sed -n 's/^  \"tag_name\": \"\\([0-9][0-9.]*\\)\",\$/\\1/p')
PIAB_RELEASE=\${PIAB_RELEASE:-$fallback}"
fi

cat <<EOF
#!/bin/bash
#
# Plone in a Box(TM): try ${NAME}
#
# Sets up a Plone 6 site with ${NAME} on this server, and a demo login for
# people you let try it: the form below has them filled in. It downloads the
# latest Plone in a Box release and runs it with these settings; see
# https://github.com/tkimnguyen/plone-in-a-box. When it's done, SSH as root and
# read /root/plone-credentials.txt for the admin and demo passwords, or open
# the server's address in a browser.
#
${udfs}

# This add-on's settings, if the form didn't send them (a server created
# through the API with only some fields); a field emptied in the form stays empty.
: "\${FRONTEND_IMAGE=${FRONTEND_IMAGE}}" "\${ADDONS=${ADDONS}}" "\${DEMO_USER=${DEMO_USER}}" "\${DEMO_ROLE=${DEMO_ROLE}}"

${release_lines}
SCRIPT_URL="https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/\${PIAB_RELEASE}/src/StackScript"

export ${names% }
set -uo pipefail
SCRIPT=\$(mktemp)
if ! curl --fail --silent --show-error --location --retry 10 --retry-delay 5 --retry-all-errors \\
    --output "\$SCRIPT" "\$SCRIPT_URL"; then
  echo "[plone-in-a-box] Could not download \$SCRIPT_URL" | tee -a /var/log/plone-in-a-box.log >&2
  exit 1
fi
exec bash "\$SCRIPT"
EOF
