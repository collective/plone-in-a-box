#!/usr/bin/env bash
#
# Send sample update notices to real chat channels, to check that each
# webhook format posts and looks right. No server is needed: it runs the
# notify script exactly as src/StackScript installs it, on this computer.
#
# Usage:
#   scripts/test-notify.sh [teams] [slack] [discord] [gchat] [mattermost] [ntfy]
#
# With no arguments it sends to every service that has a URL in the Keychain.
# Each service gets three notices: the site is ready, an update was installed,
# and an update was undone. Check in each channel that they look right.
#
# The URLs work like passwords, so they stay in the macOS Keychain as
# piab-webhook-<service> and are never printed. Copy one, then save it with
#   security add-generic-password -U -a "$USER" -s piab-webhook-teams -w "$(pbpaste)"
# (the interactive -w prompt cuts input off at 128 characters, too short for
# Teams URLs). See RELEASING.md for where to create each webhook.
#
# Needs bash, curl and python3.

set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ALL=(teams slack discord gchat mattermost ntfy)
if (( $# )); then services=("$@"); else services=("${ALL[@]}"); fi
for s in "${services[@]}"; do
  [[ " ${ALL[*]} " == *" $s "* ]] || { echo "Unknown service: $s (one of: ${ALL[*]})" >&2; exit 2; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
urlfile="$work/notify-url"

# The notify script, exactly as setup writes it, reading its URL from $urlfile.
sed -n "/^cat > \/usr\/local\/lib\/plone-in-a-box\/notify <<'EOF'\$/,/^EOF\$/p" "$REPO/src/StackScript" \
  | sed '1d;$d' | sed "s#/var/lib/plone-in-a-box/notify-url#$urlfile#" > "$work/notify"
grep -q "$urlfile" "$work/notify" || { echo "Couldn't find the notify script in src/StackScript" >&2; exit 1; }

# The same wording as setup and plone-update use.
site=http://203.0.113.7
guide=$(sed -n "s/^GUIDE=//p" "$REPO/src/StackScript")
report() {  # report <summary> <details>: the body plone-update sends
  printf '%s\n\n%s\n\n%s\n\nThe log is in %s on the server. Turn automatic updates off: sudo systemctl disable --now plone-update.timer\nUpdates and backups: %s' \
    "$site" "$1" "$2" /var/log/plone-update.log "$guide"
}
titles=(
  "Plone in a Box is ready (${site})"
  "Plone in a Box: Updated (${site})"
  "Plone in a Box: Update failed and was undone (${site})"
)
messages=(
  "Your Plone site is ready: ${site}"$'\n'"Log in as admin. Update reports will be sent here."
  "$(report "Updated: Plone 6.2.2, Volto 19.8.1, PostgreSQL 17.12 -> Plone 6.2.3, Volto 19.8.1, PostgreSQL 17.12" \
     "Database backup from before the update: /var/backups/plone/plone-2026-11-22-0412.sql.gz")"
  "$(report "Update failed and was undone: back on Plone 6.2.2, Volto 19.8.1, PostgreSQL 17.12" \
     "The site didn't come back with the new backend image, so it runs the previous one again; that build is skipped from now on. The reason is in /var/log/plone-update.log."$'\n'"Database backup from before the update: /var/backups/plone/plone-2026-11-22-0412.sql.gz")"
)

sent=0 failed=0
for s in "${services[@]}"; do
  url=$(security find-generic-password -s "piab-webhook-$s" -w 2>/dev/null) || {
    (( $# )) && { echo "$s: no URL in the Keychain (piab-webhook-$s)"; failed=$((failed+1)); }
    continue
  }
  printf '%s\n' "$url" > "$urlfile"
  for i in "${!titles[@]}"; do
    name=${titles[$i]%% (*}
    if out=$(bash "$work/notify" "${titles[$i]}" "${messages[$i]}" 2>&1); then
      echo "$s: sent \"$name\""; sent=$((sent+1))
    else
      echo "$s: FAILED \"$name\": $out"; failed=$((failed+1))
    fi
    sleep 1
  done
done

if (( sent + failed == 0 )); then
  echo "No webhook URLs in the Keychain; see the comments at the top of this script"
  exit 1
fi
echo "$sent sent, $failed failed"
(( failed == 0 ))
