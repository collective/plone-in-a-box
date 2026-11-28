#!/bin/bash
#
# Plone in a Box: add automatic updates to a server set up before release 2.12.
# Run it on the server (in your provider's browser console, or over SSH):
#
#   curl -fsSL https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/2.26/src/add-updates.sh | sudo bash
#
# It installs plone-update, the weekly plone-update.timer, plone-backup with
# the nightly plone-backup.timer, plone-restore, plone-offsite, plone-security-notices with
# its daily timer, plone-reboot with its nightly timer, failure reports, and the login message, exactly as setup does on new servers, and then runs
# plone-update once. Running it again brings these tools up to date with the release.
#
# Settings go between "sudo" and "bash", for example
#   ... | sudo NOTIFY_URL=https://ntfy.sh/your-long-random-topic bash
#   AUTO_UPDATE=no   install plone-update, but don't run it every week
#   NOTIFY_URL=URL   post update reports here (ntfy, or a Slack, Discord,
#                    Google Chat, Mattermost or Microsoft Teams webhook)
#   UPDATE_NOW=no    don't run plone-update at the end

# Everything is inside main, so bash has read the whole script before any
# command can read from standard input (the pipe this script arrives on).
main() {
  set -euo pipefail
  exec </dev/null

  local PIAB_RELEASE='2.26'
  local ref=${PIAB_ADD_UPDATES_REF:-$PIAB_RELEASE}
  local APP_DIR=/opt/plone STATE_DIR=/var/lib/plone-in-a-box
  local say_prefix='[plone-in-a-box]'
  say() { printf '%s %s\n' "$say_prefix" "$*"; }
  die() { say "$*" >&2; exit 1; }

  [[ $EUID -eq 0 ]] || die "Please run this as root: put sudo before bash"
  [[ -f "$APP_DIR/docker-compose.yml" && -f "$APP_DIR/.env" ]] \
    || die "There's no Plone in a Box site in $APP_DIR. This is for servers set up with Plone in a Box 2.0 or later."
  command -v docker >/dev/null || die "Docker isn't installed, so this isn't a Plone in a Box 2.x server"
  local s
  for s in db backend frontend; do
    [[ -n "$(docker compose --project-directory "$APP_DIR" ps -q "$s" 2>/dev/null)" ]] \
      || die "The site's $s container isn't running. Start the site first: sudo docker compose --project-directory $APP_DIR up -d"
  done

  local had_tools=0
  [[ -x /usr/local/bin/plone-update ]] && had_tools=1

  # plone-update waits for the site with "docker compose up --wait-timeout",
  # newer than the Docker Compose on some older servers. Ubuntu's automatic
  # updates don't update Docker, which comes from Docker's own repository.
  if ! docker compose up --help 2>/dev/null | grep -q -- '--wait-timeout'; then
    say "Updating Docker Compose"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --only-upgrade docker-compose-plugin >/dev/null
    docker compose up --help 2>/dev/null | grep -q -- '--wait-timeout' \
      || die "Docker Compose is too old for plone-update, and updating it didn't help: $(docker compose version)"
  fi

  # The update tools are a block of the release's provisioning script, so
  # older servers get exactly what new ones do.
  local url="https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/${ref}/src/StackScript" script block
  say "Downloading the update tools from Plone in a Box ${ref}"
  script=$(curl -fsSL --retry 5 --retry-all-errors "$url") || die "Couldn't download $url"
  block=$(sed -n '/^# >>> update tools$/,/^# <<< update tools$/p' <<<"$script")
  [[ -n "$block" ]] || die "Plone in a Box ${ref} doesn't have the update tools; use release 2.12 or later"
  # From a file, not bash -c: the block is bigger than one argument may be
  # (128 KB on Linux).
  local block_file
  block_file=$(mktemp)
  printf '%s\n' "$block" > "$block_file"
  APP_DIR="$APP_DIR" bash -euo pipefail "$block_file" </dev/null
  rm -f "$block_file"
  say "Installed plone-update and plone-backup"
  systemctl enable --now plone-backup.timer
  say "The database is backed up every night, and packed once a week (sudo plone-backup to run it now)"
  systemctl enable --now plone-backup-check.timer
  say "Once a month, the newest backup is restored into a test database to check it (sudo plone-backup-check to run it now)"
  [[ -s "$STATE_DIR/security-seen" ]] || /usr/local/bin/plone-security-notices >/dev/null 2>&1 || true
  systemctl enable --now plone-security-notices.timer
  say "Plone security announcements are passed on every day (sudo plone-security-notices to check now)"
  systemctl enable --now plone-reboot.timer
  say "The server restarts at night when Ubuntu's security updates need it (sudo systemctl disable --now plone-reboot.timer to stop)"
  if /usr/local/bin/plone-server-mail >/dev/null 2>&1; then
    say "Mail the server sends to root (such as failed security updates) now goes to the address for reports, through the site's mail settings"
  fi
  # Logs or metrics sent elsewhere: their containers with this release's
  # settings (the containers restart only if those changed).
  if [[ -s "$STATE_DIR/syslog" || -s "$STATE_DIR/otel" ]]; then
    /usr/local/lib/plone-in-a-box/compose-override || true
  fi
  say "To graph the server's and the site's numbers in a service such as Grafana Cloud: sudo plone-otel on ENDPOINT (see the setup guide)"
  say "To see how the server and site are doing, in one place: sudo plone-status (or in your browser: sudo plone-panel on)"

  # This release's security headers, on servers whose nginx setup has the
  # snippets (2.x); put back as they were if nginx doesn't take them.
  local headers=/etc/nginx/snippets/plone-headers.conf site_conf=/etc/nginx/snippets/plone-site.conf
  if [[ -f "$headers" && -f "$site_conf" ]] && ! grep -q 'Permissions-Policy' "$headers"; then
    cp -p "$headers" "$headers.before-2.27"
    cp -p "$site_conf" "$site_conf.before-2.27"
    grep -q 'Referrer-Policy' "$headers" \
      || echo 'add_header Referrer-Policy strict-origin-when-cross-origin always;' >> "$headers"
    grep -q 'Content-Security-Policy' "$headers" \
      || echo "add_header Content-Security-Policy \"frame-ancestors 'self'; base-uri 'self'; object-src 'none'\" always;" >> "$headers"
    echo 'add_header Permissions-Policy "camera=(), microphone=(), payment=(), usb=()" always;' >> "$headers"
    grep -q 'X-Powered-By' "$site_conf" || printf '\nproxy_hide_header X-Powered-By;\nproxy_hide_header X-Frame-Options;\n' >> "$site_conf"
    if nginx -t >/dev/null 2>&1 && systemctl reload nginx; then
      rm -f "$headers.before-2.27" "$site_conf.before-2.27"
      say "Added this release's security headers (Referrer-Policy, Content-Security-Policy, Permissions-Policy)"
    else
      mv "$headers.before-2.27" "$headers"
      mv "$site_conf.before-2.27" "$site_conf"
      say "nginx didn't take the new security headers, so they were left out"
    fi
  fi

  install -d -m 755 "$STATE_DIR"
  if [[ ! -s "$STATE_DIR/site-url" ]]; then
    # The address setup showed: the domain from the nginx configuration
    # (https once certbot has added a certificate), or the public IP address.
    local conf=/etc/nginx/sites-available/plone name site_url
    name=$(awk '$1 == "server_name" { sub(/;$/, "", $2); print $2; exit }' "$conf" 2>/dev/null || true)
    if [[ -n "$name" && "$name" != _ ]]; then
      if grep -q 'ssl_certificate' "$conf"; then site_url="https://${name}"; else site_url="http://${name}"; fi
    else
      site_url="http://$(curl -fsS -4 -m 10 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
    fi
    printf '%s\n' "$site_url" > "$STATE_DIR/site-url"
  fi
  local SITE_URL
  SITE_URL=$(cat "$STATE_DIR/site-url")

  # Weekly updates: on unless AUTO_UPDATE=no. Run again without AUTO_UPDATE,
  # the timer stays as it was.
  if [[ -n "${AUTO_UPDATE:-}" || $had_tools == 0 ]]; then
    case "${AUTO_UPDATE:-yes}" in
      [Nn]|[Nn][Oo]|[Ff]alse|0|[Oo]ff)
        systemctl disable --now plone-update.timer 2>/dev/null || true
        say "Automatic updates are off; run sudo plone-update to install patch releases" ;;
      *)
        systemctl enable --now plone-update.timer
        say "Plone, Volto and PostgreSQL patch releases now install automatically every week (early on Sunday)" ;;
    esac
  fi

  local notify_url
  notify_url=$(printf '%s' "${NOTIFY_URL:-}" | tr -d ' \t\r\n')
  if [[ -n "$notify_url" ]]; then
    if [[ ! "$notify_url" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]\'\"]*)?$ ]]; then
      say "Not using the notification URL: it has to start with https:// and can't contain spaces or quotes"
    else
      (umask 077; printf '%s\n' "$notify_url" > "$STATE_DIR/notify-url")
      if /usr/local/lib/plone-in-a-box/notify "Plone in a Box: updates added (${SITE_URL})" \
          "${SITE_URL} now gets Plone, Volto and PostgreSQL patch releases. Update reports will be sent here."; then
        say "Sent a notice to the notification URL"
      else
        say "Sending a notice to the notification URL failed; check the URL in $STATE_DIR/notify-url"
      fi
    fi
  fi

  case "${UPDATE_NOW:-yes}" in
    [Nn]|[Nn][Oo]|[Ff]alse|0|[Oo]ff)
      say "Done. Run sudo plone-update to install patch releases now." ;;
    *)
      say "Checking for updates now (sudo plone-update); this can take a few minutes"
      local rc=0
      /usr/local/bin/plone-update || rc=$?
      say "Done. The log of each update is in /var/log/plone-update.log."
      return "$rc" ;;
  esac
}

main "$@"
