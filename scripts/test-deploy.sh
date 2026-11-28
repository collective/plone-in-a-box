#!/usr/bin/env bash
#
# Deploy a throwaway Plone in a Box test server on Linode, DigitalOcean, AWS
# or Hetzner, run the checks from RELEASING.md against it, and delete it again.
#
# Usage:
#   scripts/test-deploy.sh linode|digitalocean|aws|hetzner [options]
#   scripts/test-deploy.sh list|cleanup linode|digitalocean|aws|hetzner
#
# Options:
#   --ref REF              branch, tag or commit to test (default: the current
#                          branch); it must be pushed to origin
#   --generated-password   deploy without an admin password, so setup generates
#                          one (default: set a random one when deploying)
#   --keep                 don't delete the server at the end (delete it later
#                          with "cleanup")
#   --keep-on-failure      like --keep, but only when a check fails or the test
#                          stops early, so you can look at the server or retry a
#                          check; it's still deleted when all checks pass or you
#                          press Ctrl-C
#   --addons "PKG ..."     install these backend add-ons, then check they are
#                          offered in Site Setup, can be activated, and survive
#                          recreating the backend and restarting the server
#   --expect-addons-skipped
#                          with --addons: expect setup to leave the add-ons out
#                          (a misspelled or invalid name), and check the site
#                          works without them and the credentials file says why
#   --frontend-image IMAGE use this frontend image, then check the frontend runs
#                          it, and that the backend add-ons and site behaviors
#                          its labels name are active, also after the restarts
#   --real-cert            get the HTTPS certificate for the server's IP address
#                          from Let's Encrypt itself (default: its test service,
#                          whose certificates these tests trust, so test servers
#                          that get the same address again don't use up
#                          Let's Encrypt's limit of 5 a week for one address).
#                          Linode and the AWS Launch Stack (--cloudformation)
#                          always use the real one: the switch isn't a field in
#                          their forms
#   --site-language CODE   create the site in this language (en, de, pt-br),
#                          then check the site's language is CODE
#   --no-starter-content   create the site without starter content, then
#                          check the site has no pages
#   --backend-image IMAGE  use this backend image (a Plone distribution, say),
#                          then check the backend runs it, also after the
#                          restarts
#   --registry-user USER   log in to the images' registry as USER, with the
#                          token in the Keychain as piab-registry-token (for
#                          private images), then check the login worked and the
#                          token isn't in the setup log or credentials file
#   --spamhaus             give the Spamhaus DQS key in the Keychain as
#                          piab-spamhaus-key, then check Spamhaus answers
#                          through it, and the key isn't in the setup log or
#                          credentials file
#   --logs                 fill in the log fields: PIAB_TEST_LOG_SERVER, and
#                          the token element in the Keychain as piab-log-token;
#                          then check plone-syslog is on
#   --metrics              fill in the graphs fields: PIAB_TEST_METRICS_ENDPOINT,
#                          PIAB_TEST_METRICS_USER, and the token in the
#                          Keychain as piab-metrics-token; then check numbers
#                          went out
#   --panel                turn on the control panel from the launch form
#                          (CONTROL_PANEL=yes: port 8443), check its login,
#                          page, buttons and limits, then turn it off again
#   --expect-backend-fallback
#                          with --backend-image: expect setup to use the
#                          official Plone backend instead (an image that can't
#                          be pulled or doesn't run Plone), and check the
#                          credentials file says why
#   --expect-frontend-fallback
#                          with --frontend-image: expect setup to use the
#                          standard Volto image instead (a bad image name), and
#                          check the credentials file says why
#   --updates              also test plone-update fully: put the backend on an
#                          older Plone patch release (PIAB_TEST_OLD_PLONE,
#                          default 6.2.2), check that a failed update is undone
#                          and then skipped, and that a real update installs
#                          the newest one after a database backup
#   --notify               set the notification URL to a new random topic on
#                          ntfy.sh, and check the notices arrive there (the
#                          setup notice, and with --updates the reports)
#   --notify-url URL       like --notify, with this notification URL (an ntfy
#                          topic you're subscribed to, to watch the notices)
#   --demo-user NAME       create the demo login NAME, then check the credentials
#                          file gives its password, it can log in with its role,
#                          also after the restarts
#   --demo-password PW     with --demo-user: set its password when deploying,
#                          and check that works and isn't in the credentials
#                          file (default: generated, read from that file)
#   --demo-roles ROLES     with --demo-user: its roles, separated by commas
#                          (default: empty, so the frontend image's suggestion,
#                          or Site Administrator)
#   --expect-demo-roles ROLES
#                          with --demo-user: the roles to check it has
#                          (default: --demo-roles, or Site Administrator)
#   --cloudformation       AWS: create the server the way the Launch Stack
#                          button does, as a CloudFormation stack (named like
#                          the server) from src/aws/cloudformation.yaml, with
#                          Release set to the commit tested. Needs the
#                          piab-test-cloudformation policy (RELEASING.md)
#   --linode-script FILE   Linode: put FILE in the test StackScript instead of
#                          src/StackScript, e.g. a per-add-on StackScript from
#                          scripts/linode-addon-stackscript.sh --ref REF
#   --mail ADDRESS         set up email through an SMTP relay service, with a
#                          test email (and with --updates the reports) to
#                          ADDRESS. The SMTP username and password come from the
#                          Keychain (piab-smtp-user, piab-smtp-password), the
#                          From address from piab-email-from or
#                          PIAB_TEST_EMAIL_FROM, and the server from
#                          PIAB_TEST_SMTP_HOST (default mail.smtp2go.com) and
#                          PIAB_TEST_SMTP_PORT (default 587).
#
# "list" shows the test servers that exist; "cleanup" deletes all of them.
# Only servers tagged piab-test are ever touched.
#
# Needs: curl, jq, ssh, git, nc, and the AWS CLI for aws. API tokens come from
# the macOS Keychain (services piab-linode-token, piab-do-token and
# piab-hetzner-token) or from LINODE_TOKEN / DIGITALOCEAN_TOKEN / HCLOUD_TOKEN. AWS access keys come from the Keychain
# (piab-aws-access-key-id and piab-aws-secret-access-key), or from the usual
# AWS_PROFILE / AWS_ACCESS_KEY_ID settings. The test servers get the SSH key
# ~/.ssh/piab_test_ed25519 (or PIAB_TEST_SSH_KEY). Optional: PIAB_TEST_REGION,
# PIAB_LINODE_FIREWALL_ID, PIAB_LINODE_TYPE (default g6-nanode-1), PIAB_DO_SIZE (default s-1vcpu-1gb),
# PIAB_AWS_INSTANCE_TYPE (default t3.small),
# PIAB_TEST_UBUNTU (Ubuntu release: 26.04, the default, or 24.04),
# PIAB_HETZNER_SERVER_TYPE (default cpx02; an Arm type, cax..., works too),
# PIAB_TEST_LAUNCHER=short (DigitalOcean, AWS, Hetzner: use the three-line
# launcher from the docs instead of src/user-data.sh; with
# --generated-password, its CHANGE-ME placeholder is left in place).
#
# Linode deploys use the private StackScript "plone-in-a-box-test", which this
# script overwrites with src/StackScript from REF. DigitalOcean, AWS and Hetzner deploys
# paste src/user-data.sh from REF as user data, set to download src/StackScript
# from the same commit. On AWS, the script also creates (once) a key pair named
# piab-test-<fingerprint> for this computer's key, and a security group named
# piab-test in the default VPC, allowing SSH, HTTP and
# HTTPS.

set -euo pipefail

# On a Mac, stay awake until the test is done: idle sleep stalls the checks over
# SSH, and makes them time out or fail.
if [[ "$(uname)" == Darwin && -z "${PIAB_TEST_CAFFEINATED:-}" ]] && command -v caffeinate >/dev/null; then
  PIAB_TEST_CAFFEINATED=1 exec caffeinate -i "$0" "$@"
fi

TAG=piab-test
UBUNTU=${PIAB_TEST_UBUNTU:-26.04}
case "$UBUNTU" in
  24.04) UBUNTU_CODENAME=noble ;;
  26.04) UBUNTU_CODENAME=resolute ;;
  *) echo "error: PIAB_TEST_UBUNTU must be 24.04 or 26.04" >&2; exit 1 ;;
esac
LINODE_STACKSCRIPT_LABEL=plone-in-a-box-test
SSH_KEY="${PIAB_TEST_SSH_KEY:-$HOME/.ssh/piab_test_ed25519}"

PROVIDER="" ACTION=deploy REF="" GENERATED=0 KEEP=0 KEEP_ON_FAILURE=0 ADDONS="" ADDONS_SKIPPED=0 FRONTEND_IMAGE="" FRONTEND_FALLBACK=0 BACKEND_IMAGE="" BACKEND_FALLBACK=0 SITE_LANGUAGE="" NO_STARTER=0 REAL_CERT=0 UPDATES=0 NOTIFY_URL="" MAIL_TO="" REGISTRY_USER="" REGISTRY_TOKEN=""
SMTP_HOST="" SMTP_PORT="" SMTP_USER="" SMTP_PASSWORD="" EMAIL_FROM="" SPAMHAUS=0 SPAMHAUS_KEY=""
PANEL=0 LOGS=0 LOG_SERVER="" LOG_TOKEN="" METRICS=0 METRICS_ENDPOINT="" METRICS_USER="" METRICS_TOKEN=""
CLOUDFORMATION=0 DEMO_USER="" DEMO_PASSWORD_SET="" DEMO_ROLES="" EXPECT_DEMO_ROLES="" LINODE_SCRIPT=""
SERVER_ID="" IP="" FAILURES=0

die() { echo "error: $*" >&2; exit 1; }
say() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
pass() { say "PASS  $*"; }
fail() { say "FAIL  $*"; FAILURES=$((FAILURES + 1)); }
check() { local what=$1; shift; if "$@" >/dev/null 2>&1; then pass "$what"; else fail "$what"; fi; }

usage() { sed -n '3,/^# Only servers tagged/p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

case "${1:-}" in
  linode|digitalocean|aws|hetzner) PROVIDER=$1 ;;
  list|cleanup) ACTION=$1; PROVIDER=${2:-}; shift ;;
  *) usage ;;
esac
shift
case "$PROVIDER" in linode|digitalocean|aws|hetzner) ;; *) usage ;; esac
while (( $# )); do
  case "$1" in
    --ref) REF=${2:?--ref needs a value}; shift ;;
    --generated-password) GENERATED=1 ;;
    --keep) KEEP=1 ;;
    --keep-on-failure) KEEP_ON_FAILURE=1 ;;
    --addons) ADDONS=${2:?--addons needs a value}; shift ;;
    --expect-addons-skipped) ADDONS_SKIPPED=1 ;;
    --frontend-image) FRONTEND_IMAGE=${2:?--frontend-image needs a value}; shift ;;
    --expect-frontend-fallback) FRONTEND_FALLBACK=1 ;;
    --backend-image) BACKEND_IMAGE=${2:?--backend-image needs a value}; shift ;;
    --registry-user) REGISTRY_USER=${2:?--registry-user needs a value}; shift ;;
    --spamhaus) SPAMHAUS=1 ;;
    --logs) LOGS=1 ;;
    --metrics) METRICS=1 ;;
    --panel) PANEL=1 ;;
    --site-language) SITE_LANGUAGE=${2:?--site-language needs a value}; shift ;;
    --no-starter-content) NO_STARTER=1 ;;
    --real-cert) REAL_CERT=1 ;;
    --expect-backend-fallback) BACKEND_FALLBACK=1 ;;
    --updates) UPDATES=1 ;;
    --cloudformation) CLOUDFORMATION=1 ;;
    --demo-user) DEMO_USER=${2:?--demo-user needs a value}; shift ;;
    --demo-password) DEMO_PASSWORD_SET=${2:?--demo-password needs a value}; shift
      [[ "$DEMO_PASSWORD_SET" =~ ^[A-Za-z0-9._-]{12,}$ ]] || die "--demo-password: 12 or more letters, digits, . _ -" ;;
    --demo-roles) DEMO_ROLES=${2:?--demo-roles needs a value}; shift ;;
    --expect-demo-roles) EXPECT_DEMO_ROLES=${2:?--expect-demo-roles needs a value}; shift ;;
    --linode-script) LINODE_SCRIPT=${2:?--linode-script needs a file}; shift
      [[ -f "$LINODE_SCRIPT" ]] || die "--linode-script: no file $LINODE_SCRIPT" ;;
    --notify) NOTIFY_URL="https://ntfy.sh/piab-test-$(openssl rand -hex 12)" ;;
    --notify-url)
      NOTIFY_URL=${2:?--notify-url needs a value}; shift
      [[ "$NOTIFY_URL" == https://* ]] || NOTIFY_URL="https://$NOTIFY_URL"
      [[ "$NOTIFY_URL" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]\'\"]*)?$ ]] || die "--notify-url: not a URL" ;;
    --mail)
      MAIL_TO=${2:?--mail needs an address}; shift
      [[ "$MAIL_TO" =~ ^[^@[:space:]]+@[A-Za-z0-9.-]+$ ]] || die "--mail: not an email address" ;;
    *) usage ;;
  esac
  shift
done
[[ "$DEMO_ROLES$EXPECT_DEMO_ROLES" =~ ^[A-Za-z0-9\ ,._-]*$ ]] || die "--demo-roles: role names separated by commas"
if [[ -z "$EXPECT_DEMO_ROLES" ]]; then
  EXPECT_DEMO_ROLES=${DEMO_ROLES:-Site Administrator}
  # With email, setup gives Editor instead of Site Administrator.
  [[ -z "$MAIL_TO" ]] || EXPECT_DEMO_ROLES=$(sed -E 's/(^|,)[[:space:]]*Site Administrator[[:space:]]*(,|$)/\1Editor\2/g' <<<"$EXPECT_DEMO_ROLES")
fi

(( ! CLOUDFORMATION )) || [[ "$PROVIDER" == aws ]] || die "--cloudformation is for aws"
(( ! CLOUDFORMATION )) || (( ! GENERATED )) || die "--cloudformation needs an admin password; the form requires one"
tools="curl jq ssh git nc"
[[ "$PROVIDER" == aws ]] && tools+=" aws"
for tool in $tools; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

# --- API access ---------------------------------------------------------------

keychain_token() {
  command -v security >/dev/null && security find-generic-password -s "$1" -w 2>/dev/null
}
if [[ -n "$MAIL_TO" ]]; then
  SMTP_HOST=${PIAB_TEST_SMTP_HOST:-mail.smtp2go.com} SMTP_PORT=${PIAB_TEST_SMTP_PORT:-587}
  SMTP_USER=$(keychain_token piab-smtp-user || true)
  SMTP_PASSWORD=$(keychain_token piab-smtp-password || true)
  EMAIL_FROM=${PIAB_TEST_EMAIL_FROM:-$(keychain_token piab-email-from || true)}
  [[ -n "$SMTP_USER" && -n "$SMTP_PASSWORD" && -n "$EMAIL_FROM" ]] \
    || die "--mail needs piab-smtp-user, piab-smtp-password and piab-email-from in the Keychain"
fi
if [[ -n "$REGISTRY_USER" ]]; then
  [[ "$REGISTRY_USER" =~ ^[A-Za-z0-9._-]+$ ]] || die "--registry-user: letters, digits, . _ - only"
  REGISTRY_TOKEN=$(keychain_token piab-registry-token || true)
  [[ "$REGISTRY_TOKEN" =~ ^[A-Za-z0-9._-]+$ ]] || die "--registry-user needs a token in the Keychain as piab-registry-token"
fi
if (( SPAMHAUS )); then
  SPAMHAUS_KEY=$(keychain_token piab-spamhaus-key || true)
  [[ "$SPAMHAUS_KEY" =~ ^[A-Za-z0-9]+$ ]] || die "--spamhaus needs a key in the Keychain as piab-spamhaus-key"
fi
if (( LOGS )); then
  LOG_SERVER=${PIAB_TEST_LOG_SERVER:-}
  [[ "$LOG_SERVER" =~ ^[A-Za-z0-9.-]+:[0-9]+$ ]] || die "--logs needs PIAB_TEST_LOG_SERVER, as HOST:PORT"
  LOG_TOKEN=$(keychain_token piab-log-token || true)
fi
CONTROL_PANEL=no
(( PANEL )) && CONTROL_PANEL=yes
if (( METRICS )); then
  METRICS_ENDPOINT=${PIAB_TEST_METRICS_ENDPOINT:-}
  METRICS_USER=${PIAB_TEST_METRICS_USER:-}
  [[ "$METRICS_ENDPOINT" == https://* ]] || die "--metrics needs PIAB_TEST_METRICS_ENDPOINT"
  METRICS_TOKEN=$(keychain_token piab-metrics-token || true)
  [[ -n "$METRICS_TOKEN" ]] || die "--metrics needs a token in the Keychain as piab-metrics-token"
fi
TOKEN=""
if [[ "$PROVIDER" == linode ]]; then
  TOKEN="${LINODE_TOKEN:-$(keychain_token piab-linode-token || true)}"
  API=https://api.linode.com/v4
elif [[ "$PROVIDER" == digitalocean ]]; then
  TOKEN="${DIGITALOCEAN_TOKEN:-$(keychain_token piab-do-token || true)}"
  API=https://api.digitalocean.com/v2
elif [[ "$PROVIDER" == hetzner ]]; then
  TOKEN="${HCLOUD_TOKEN:-$(keychain_token piab-hetzner-token || true)}"
  API=https://api.hetzner.cloud/v1
else
  if [[ -z "${AWS_PROFILE:-}" && -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    AWS_ACCESS_KEY_ID=$(keychain_token piab-aws-access-key-id || true)
    AWS_SECRET_ACCESS_KEY=$(keychain_token piab-aws-secret-access-key || true)
    [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]] \
      || die "no AWS access keys (see the comments at the top of this script)"
    # A secret saved as the key ID would be echoed back in AWS's error messages.
    [[ "$AWS_ACCESS_KEY_ID" =~ ^AKIA[A-Z0-9]{16}$ && ${#AWS_SECRET_ACCESS_KEY} -eq 40 ]] \
      || die "the Keychain's AWS values don't look right: piab-aws-access-key-id should be 20 characters starting with AKIA, piab-aws-secret-access-key 40 characters"
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  fi
  export AWS_DEFAULT_REGION="${PIAB_TEST_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}" AWS_PAGER=""
  TOKEN=aws
fi
[[ -n "$TOKEN" ]] || die "no API token for $PROVIDER (see the comments at the top of this script)"

ec2() { aws ec2 --output json "$@"; }

# api METHOD PATH [JSON body] [extra header]: prints the response body, fails on
# an HTTP error. The token goes to curl on stdin, so it isn't in the process list.
api() {
  local method=$1 path=$2 data=${3:-} header=${4:-} out code body
  local args=(-sS -X "$method" -H 'Content-Type: application/json' -w '\n%{http_code}')
  [[ -n "$data" ]] && args+=(--data "$data")
  [[ -n "$header" ]] && args+=(-H "$header")
  out=$(printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" | curl -K - "${args[@]}" "$API$path") \
    || return 1
  code=${out##*$'\n'}
  body=${out%$'\n'*}
  if (( code >= 300 )); then
    echo "$method $path: HTTP $code: $(jq -c '.errors // .error // .message // .' <<<"$body" 2>/dev/null || echo "$body")" >&2
    return 1
  fi
  printf '%s' "$body"
}

list_servers() {
  if [[ "$PROVIDER" == linode ]]; then
    api GET /linode/instances '' "X-Filter: {\"tags\": \"$TAG\"}" \
      | jq -r '.data[] | "\(.id)\t\(.label)\t\(.ipv4[0])\t\(.status)"'
  elif [[ "$PROVIDER" == hetzner ]]; then
    api GET "/servers?label_selector=$TAG&per_page=50" \
      | jq -r '.servers[] | "\(.id)\t\(.name)\t\(.public_net.ipv4.ip // "-")\t\(.status)"'
  elif [[ "$PROVIDER" == digitalocean ]]; then
    api GET "/droplets?tag_name=$TAG&per_page=200" \
      | jq -r '.droplets[] | "\(.id)\t\(.name)\t\((.networks.v4[] | select(.type == "public") | .ip_address) // "-")\t\(.status)"'
  else
    # Instances, except those of a stack: the stack is listed (and deleted) instead.
    ec2 describe-instances --filters "Name=tag:$TAG,Values=true" \
        Name=instance-state-name,Values=pending,running,stopping,stopped \
      | jq -r '.Reservations[].Instances[]
          | select([.Tags[]? | .Key] | index("aws:cloudformation:stack-name") | not)
          | "\(.InstanceId)\t\(([.Tags[]? | select(.Key == "Name") | .Value][0]) // "-")\t\(.PublicIpAddress // "-")\t\(.State.Name)"'
    aws cloudformation list-stacks --output json \
        --stack-status-filter CREATE_IN_PROGRESS CREATE_COMPLETE CREATE_FAILED ROLLBACK_COMPLETE ROLLBACK_FAILED DELETE_FAILED \
      | jq -r --arg tag "$TAG" '.StackSummaries[] | select(.StackName | startswith($tag + "-"))
          | "\(.StackName)\t\(.StackName) (stack)\t-\t\(.StackStatus)"'
  fi
}

delete_server() {
  if [[ "$PROVIDER" == linode ]]; then
    api DELETE "/linode/instances/$1" >/dev/null
  elif [[ "$PROVIDER" == hetzner ]]; then
    api DELETE "/servers/$1" >/dev/null
  elif [[ "$PROVIDER" == digitalocean ]]; then
    api DELETE "/droplets/$1" >/dev/null
  elif [[ "$1" == i-* ]]; then
    ec2 terminate-instances --instance-ids "$1" >/dev/null
  else
    # A test stack (--cloudformation). Its instance has termination protection
    # and its address is kept when the stack is deleted, as for site owners:
    # turn the protection off, delete the stack, then release the address.
    local instance alloc
    instance=$(aws cloudformation describe-stack-resources --stack-name "$1" --logical-resource-id Instance \
      --query 'StackResources[0].PhysicalResourceId' --output text 2>/dev/null || true)
    alloc=$(aws ec2 describe-addresses --filters "Name=tag:aws:cloudformation:stack-name,Values=$1" \
      --query 'Addresses[0].AllocationId' --output text 2>/dev/null || true)
    if [[ "$instance" == i-* ]]; then
      ec2 modify-instance-attribute --instance-id "$instance" --no-disable-api-termination || return 1
    fi
    aws cloudformation delete-stack --stack-name "$1" \
      && aws cloudformation wait stack-delete-complete --stack-name "$1" || return 1
    if [[ "$alloc" == eipalloc-* ]]; then
      ec2 release-address --allocation-id "$alloc"
    fi
  fi
}

if [[ "$ACTION" != deploy ]]; then
  servers=$(list_servers)
  if [[ -z "$servers" ]]; then
    echo "No $PROVIDER servers tagged $TAG."
    exit 0
  fi
  echo "$servers"
  if [[ "$ACTION" == cleanup ]]; then
    while IFS=$'\t' read -r id label _; do
      delete_server "$id" && echo "Deleted $label ($id)"
    done <<<"$servers"
  fi
  exit 0
fi

# --- What to deploy -------------------------------------------------------------

[[ -f "$SSH_KEY" && -f "$SSH_KEY.pub" ]] \
  || die "SSH key $SSH_KEY not found; create it with: ssh-keygen -t ed25519 -f $SSH_KEY -C piab-test -N ''"

cd "$(git rev-parse --show-toplevel)"
REF=${REF:-$(git rev-parse --abbrev-ref HEAD)}
git fetch -q origin
SHA=$(git rev-parse --verify -q "origin/$REF^{commit}" || git rev-parse --verify -q "$REF^{commit}") \
  || die "can't find $REF"
git branch -r --contains "$SHA" 2>/dev/null | grep -q 'origin/' \
  || git ls-remote --tags origin | grep -q "^$SHA" \
  || die "$REF ($SHA) isn't pushed to origin; the server downloads it from GitHub"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/piab-test.XXXXXX")
# The site's HTTPS certificate comes from Let's Encrypt's test service unless
# --real-cert: trust its roots too, so the checks still verify the certificate.
if (( ! REAL_CERT )); then
  cat /etc/ssl/cert.pem > "$WORK/ca.pem" 2>/dev/null || cat /etc/ssl/certs/ca-certificates.crt > "$WORK/ca.pem"
  for root in x1 x2; do
    curl -fsS -m 30 "https://letsencrypt.org/certs/staging/letsencrypt-stg-root-$root.pem" >> "$WORK/ca.pem" \
      || die "couldn't download Let's Encrypt's test service roots"
  done
  export CURL_CA_BUNDLE="$WORK/ca.pem"
fi
chmod 700 "$WORK"
# The random suffix keeps names unique when several runs start at once.
NAME="$TAG-$PROVIDER-$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 2)"
ADMIN_PASSWORD=""
(( GENERATED )) || ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-20)

say "Testing $REF ($(git rev-parse --short "$SHA")) on $PROVIDER, Ubuntu $UBUNTU, as $NAME"
say "Notes, passwords and logs: $WORK"
{
  echo "ref=$REF sha=$SHA name=$NAME"
  (( GENERATED )) && echo "admin password: generated on the server" || echo "admin password: $ADMIN_PASSWORD"
  [[ -z "$ADDONS" ]] || echo "add-ons: $ADDONS"
  [[ -z "$FRONTEND_IMAGE" ]] || echo "frontend image: $FRONTEND_IMAGE"
  [[ -z "$BACKEND_IMAGE" ]] || echo "backend image: $BACKEND_IMAGE"
  [[ -z "$NOTIFY_URL" ]] || echo "notification URL: $NOTIFY_URL"
} > "$WORK/notes.txt"
[[ "$ADDONS" != *"'"* ]] || die "--addons can't contain a single quote"
(( ! ADDONS_SKIPPED )) || [[ -n "$ADDONS" ]] || die "--expect-addons-skipped needs --addons"
[[ "$FRONTEND_IMAGE" != *[\'\|\&]* ]] || die "--frontend-image can't contain ', | or &"
(( ! FRONTEND_FALLBACK )) || [[ -n "$FRONTEND_IMAGE" ]] || die "--expect-frontend-fallback needs --frontend-image"
[[ "$BACKEND_IMAGE" != *[\'\|\&]* ]] || die "--backend-image can't contain ', | or &"
[[ "$SITE_LANGUAGE" =~ ^[a-z-]*$ ]] || die "--site-language: a language code such as de or pt-br"
STAGING=""
(( REAL_CERT )) || STAGING=yes
STARTER_CONTENT=""
(( ! NO_STARTER )) || STARTER_CONTENT=no
(( ! BACKEND_FALLBACK )) || [[ -n "$BACKEND_IMAGE" ]] || die "--expect-backend-fallback needs --backend-image"

cleanup_on_exit() {
  local status=$?
  if [[ -n "$SERVER_ID" ]]; then
    if (( KEEP )) || { (( KEEP_ON_FAILURE )) && (( status != 0 && status != 130 )); }; then
      say "Kept $NAME ($SERVER_ID) at $IP. Delete it with: $0 cleanup $PROVIDER"
    else
      say "Deleting $NAME"
      delete_server "$SERVER_ID" || say "Couldn't delete $NAME ($SERVER_ID); run: $0 cleanup $PROVIDER"
    fi
  fi
  exit "$status"
}
trap cleanup_on_exit EXIT
trap 'exit 130' INT TERM

# The launcher, set to the admin password and to download this exact commit.
launcher() {
  local text
  if [[ "${PIAB_TEST_LAUNCHER:-}" == short ]]; then
    # The three-line launcher from the README and setup guide.
    local obs_lines=""
    [[ -z "$LOG_SERVER$METRICS_ENDPOINT" ]] || obs_lines=$(obs_exports)
    printf '%s\n' '#!/bin/bash' \
      "export ADMIN_PASSWORD='${ADMIN_PASSWORD:-CHANGE-ME}'" \
      ${ADDONS:+"export ADDONS='$ADDONS'"} \
      ${FRONTEND_IMAGE:+"export FRONTEND_IMAGE='$FRONTEND_IMAGE'"} \
      ${BACKEND_IMAGE:+"export BACKEND_IMAGE='$BACKEND_IMAGE'"} \
      ${REGISTRY_USER:+"export REGISTRY_USER='$REGISTRY_USER'" "export REGISTRY_TOKEN='$REGISTRY_TOKEN'"} \
      ${SPAMHAUS_KEY:+"export SPAMHAUS_KEY='$SPAMHAUS_KEY'"} \
      ${SITE_LANGUAGE:+"export SITE_LANGUAGE='$SITE_LANGUAGE'"} \
      ${STARTER_CONTENT:+"export STARTER_CONTENT='$STARTER_CONTENT'"} \
      ${STAGING:+"export LETSENCRYPT_STAGING='yes'"} \
      ${DEMO_USER:+"export DEMO_USER='$DEMO_USER'"} \
      ${DEMO_PASSWORD_SET:+"export DEMO_PASSWORD='$DEMO_PASSWORD_SET'"} \
      ${DEMO_ROLES:+"export DEMO_ROLES='$DEMO_ROLES'"} \
      ${NOTIFY_URL:+"export NOTIFY_URL='$NOTIFY_URL'"} \
      ${MAIL_TO:+"$(mail_exports)"} \
      ${obs_lines:+"$obs_lines"} \
      "export CONTROL_PANEL='$CONTROL_PANEL'" \
      "curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/$SHA/src/StackScript && bash /root/plone-in-a-box.sh"
    return
  fi
  text=$(git show "$SHA:src/user-data.sh" \
    | sed -e "s/^export ADMIN_PASSWORD=''$/export ADMIN_PASSWORD='$ADMIN_PASSWORD'/" \
          -e "s|^export ADDONS=''$|export ADDONS='${ADDONS//&/\\&}'|" \
          -e "s|^export FRONTEND_IMAGE=''$|export FRONTEND_IMAGE='$FRONTEND_IMAGE'|" \
          -e "s|^export BACKEND_IMAGE=''$|export BACKEND_IMAGE='$BACKEND_IMAGE'|" \
          -e "s|^export REGISTRY_USER=''$|export REGISTRY_USER='$REGISTRY_USER'|" \
          -e "s|^export REGISTRY_TOKEN=''$|export REGISTRY_TOKEN='$REGISTRY_TOKEN'|" \
          -e "s|^export SPAMHAUS_KEY=''$|export SPAMHAUS_KEY='$SPAMHAUS_KEY'|" \
          -e "s|^export SITE_LANGUAGE='en'$|export SITE_LANGUAGE='${SITE_LANGUAGE:-en}'|" \
          -e "s|^export STARTER_CONTENT='yes'$|export STARTER_CONTENT='${STARTER_CONTENT:-yes}'|" \
          -e "s|^export DEMO_USER=''$|export DEMO_USER='$DEMO_USER'|" \
          -e "s|^export DEMO_PASSWORD=''$|export DEMO_PASSWORD='$DEMO_PASSWORD_SET'|" \
          -e "s|^export DEMO_ROLES=''$|export DEMO_ROLES='$DEMO_ROLES'|" \
          -e "s|^export NOTIFY_URL=''$|export NOTIFY_URL='${NOTIFY_URL//&/\\&}'|" \
          -e "s/^export CONTROL_PANEL='no'$/export CONTROL_PANEL='$CONTROL_PANEL'/" \
          -e "s/^PIAB_RELEASE='[^']*'$/PIAB_RELEASE='$SHA'/")
  if [[ -n "$STAGING" ]]; then
    text=$(awk -v line="export LETSENCRYPT_STAGING='yes'" '/^export SITE_TIMEZONE=/ { print line } 1' <<<"$text")
    grep -q "^export LETSENCRYPT_STAGING='yes'$" <<<"$text" || die "couldn't set LETSENCRYPT_STAGING in src/user-data.sh"
  fi
  grep -q "^PIAB_RELEASE='$SHA'$" <<<"$text" || die "couldn't set PIAB_RELEASE in src/user-data.sh"
  [[ -z "$ADDONS" ]] || grep -qF "export ADDONS='$ADDONS'" <<<"$text" || die "couldn't set ADDONS in src/user-data.sh"
  [[ -z "$FRONTEND_IMAGE" ]] || grep -qF "export FRONTEND_IMAGE='$FRONTEND_IMAGE'" <<<"$text" \
    || die "couldn't set FRONTEND_IMAGE in src/user-data.sh"
  [[ -z "$BACKEND_IMAGE" ]] || grep -qF "export BACKEND_IMAGE='$BACKEND_IMAGE'" <<<"$text" \
    || die "couldn't set BACKEND_IMAGE in src/user-data.sh"
  [[ -z "$REGISTRY_USER" ]] || grep -qF "export REGISTRY_TOKEN='$REGISTRY_TOKEN'" <<<"$text" \
    || die "couldn't set REGISTRY_USER and REGISTRY_TOKEN in src/user-data.sh"
  [[ -z "$SPAMHAUS_KEY" ]] || grep -qF "export SPAMHAUS_KEY='$SPAMHAUS_KEY'" <<<"$text" \
    || die "couldn't set SPAMHAUS_KEY in src/user-data.sh"
  [[ -z "$NOTIFY_URL" ]] || grep -qF "export NOTIFY_URL='$NOTIFY_URL'" <<<"$text" \
    || die "couldn't set NOTIFY_URL in src/user-data.sh"
  [[ -z "$DEMO_USER" ]] || grep -qF "export DEMO_USER='$DEMO_USER'" <<<"$text" \
    || die "couldn't set DEMO_USER in src/user-data.sh"
  if [[ -n "$MAIL_TO" ]]; then
    # Values with any characters: replace the lines, quoted for bash.
    text=$(MAIL_LINES="$(mail_exports)" awk '
      BEGIN { n = split(ENVIRON["MAIL_LINES"], l, "\n"); for (i = 1; i <= n; i++) { split(l[i], kv, "="); m[kv[1]] = l[i] } }
      { split($0, kv, "="); if (kv[1] in m) print m[kv[1]]; else print }' <<<"$text")
    grep -q "^export SMTP_HOST=$SMTP_HOST$" <<<"$text" || die "couldn't set the email settings in src/user-data.sh"
  fi
  if [[ -n "$LOG_SERVER$METRICS_ENDPOINT" ]]; then
    text=$(OBS_LINES="$(obs_exports)" awk '
      BEGIN { n = split(ENVIRON["OBS_LINES"], l, "\n"); for (i = 1; i <= n; i++) { split(l[i], kv, "="); m[kv[1]] = l[i] } }
      { split($0, kv, "="); if (kv[1] in m) print m[kv[1]]; else print }' <<<"$text")
    grep -q "^export LOG_SERVER=$LOG_SERVER$" <<<"$text" || die "couldn't set the log and graphs settings in src/user-data.sh"
  fi
  printf '%s\n' "$text"
}
# The log and graphs settings as export lines, quoted for bash.
obs_exports() {
  local var
  for var in LOG_SERVER LOG_TOKEN METRICS_ENDPOINT METRICS_USER METRICS_TOKEN; do
    printf 'export %s=%q\n' "$var" "${!var}"
  done
}
# The email settings as export lines, quoted for bash.
mail_exports() {
  local var
  for var in SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASSWORD EMAIL_FROM; do
    printf 'export %s=%q\n' "$var" "${!var}"
  done
  printf 'export REPORT_EMAIL=%q' "$MAIL_TO"
}

# --- Create the server ------------------------------------------------------------

if [[ "$PROVIDER" == linode ]]; then
  REGION=${PIAB_TEST_REGION:-ca-central}
  STACKSCRIPT_ID=$(api GET /linode/stackscripts '' \
      "X-Filter: {\"label\": \"$LINODE_STACKSCRIPT_LABEL\", \"mine\": true}" | jq -r '.data[0].id // empty')
  [[ -n "$STACKSCRIPT_ID" ]] || die "no StackScript named $LINODE_STACKSCRIPT_LABEL in this Linode account"
  if [[ -n "$LINODE_SCRIPT" ]]; then
    say "Updating StackScript $LINODE_STACKSCRIPT_LABEL ($STACKSCRIPT_ID) to $LINODE_SCRIPT"
  else
    say "Updating StackScript $LINODE_STACKSCRIPT_LABEL ($STACKSCRIPT_ID) to src/StackScript from $REF"
  fi
  api PUT "/linode/stackscripts/$STACKSCRIPT_ID" "$(if [[ -n "$LINODE_SCRIPT" ]]; then cat "$LINODE_SCRIPT"; else git show "$SHA:src/StackScript"; fi | jq -Rs \
      --arg note "Test $REF ($(git rev-parse --short "$SHA"))" \
      '{script: ., rev_note: $note, images: ["linode/ubuntu24.04", "linode/ubuntu26.04"]}')" >/dev/null
  ROOT_PASS=$(openssl rand -base64 33 | tr -d '\n')
  body=$(jq -nc --arg region "$REGION" --arg label "$NAME" --arg tag "$TAG" --arg root "$ROOT_PASS" \
      --arg key "$(cat "$SSH_KEY.pub")" --argjson ss "$STACKSCRIPT_ID" --arg pw "$ADMIN_PASSWORD" \
      --arg fw "${PIAB_LINODE_FIREWALL_ID:-}" --arg ubuntu "$UBUNTU" --arg addons "$ADDONS" \
      --arg frontend "$FRONTEND_IMAGE" --arg backend "$BACKEND_IMAGE" --arg reg_user "$REGISTRY_USER" --arg reg_token "$REGISTRY_TOKEN" --arg spamhaus "$SPAMHAUS_KEY" --arg lang "${SITE_LANGUAGE:-en}" --arg content "${STARTER_CONTENT:-yes}" --arg demo "$DEMO_USER" --arg demopw "$DEMO_PASSWORD_SET" --arg roles "$DEMO_ROLES" --arg type "${PIAB_LINODE_TYPE:-g6-nanode-1}" --arg notify "$NOTIFY_URL" \
      --arg smtp_host "$SMTP_HOST" --arg smtp_port "$SMTP_PORT" --arg smtp_user "$SMTP_USER" \
      --arg smtp_password "$SMTP_PASSWORD" --arg email_from "$EMAIL_FROM" --arg report_email "$MAIL_TO" \
      --arg log_server "$LOG_SERVER" --arg log_token "$LOG_TOKEN" --arg metrics_endpoint "$METRICS_ENDPOINT" \
      --arg metrics_user "$METRICS_USER" --arg metrics_token "$METRICS_TOKEN" --arg panel "$CONTROL_PANEL" \
      '{region: $region, type: $type, image: ("linode/ubuntu" + $ubuntu), label: $label, tags: [$tag],
        root_pass: $root, authorized_keys: [$key], stackscript_id: $ss,
        # Only the fields that are set, so older releases (without them) work too.
        stackscript_data: ({ADMIN_PASSWORD: $pw, ADDONS: $addons, FRONTEND_IMAGE: $frontend, BACKEND_IMAGE: $backend, REGISTRY_USER: $reg_user, REGISTRY_TOKEN: $reg_token, SITE_LANGUAGE: $lang, STARTER_CONTENT: $content, DEMO_USER: $demo,
            DEMO_PASSWORD: $demopw, DEMO_ROLES: $roles, NOTIFY_URL: $notify,
            SMTP_HOST: $smtp_host, SMTP_PORT: $smtp_port, SMTP_USER: $smtp_user, SMTP_PASSWORD: $smtp_password,
            EMAIL_FROM: $email_from, REPORT_EMAIL: $report_email, SPAMHAUS_KEY: $spamhaus,
            LOG_SERVER: $log_server, LOG_TOKEN: $log_token, METRICS_ENDPOINT: $metrics_endpoint,
            METRICS_USER: $metrics_user, METRICS_TOKEN: $metrics_token,
            CONTROL_PANEL: (if $panel == "yes" then "yes" else "" end)}
          | with_entries(select(.value != ""))),
        booted: true}
       + (if $fw == "" then {} else {firewall_id: ($fw | tonumber)} end)')
  created=$(api POST /linode/instances "$body")
  SERVER_ID=$(jq -r '.id' <<<"$created")
  IP=$(jq -r '.ipv4[0]' <<<"$created")
elif [[ "$PROVIDER" == hetzner ]]; then
  REGION=${PIAB_TEST_REGION:-hel1}
  fingerprint=$(ssh-keygen -l -E md5 -f "$SSH_KEY.pub" | awk '{print $2}' | sed 's/^MD5://')
  key_id=$(api GET "/ssh_keys?fingerprint=$fingerprint" | jq -r '.ssh_keys[0].id // empty')
  if [[ -z "$key_id" ]]; then
    # Named after the fingerprint, since key names must be unique in a project
    # and each computer running these tests has its own key.
    key_name="$TAG-$(tr -d : <<<"$fingerprint" | cut -c1-8)"
    say "Adding the test SSH key to the Hetzner project as $key_name"
    # If another run adds the key at the same moment, use the one it added.
    key_id=$(api POST /ssh_keys "$(jq -nc --arg k "$(cat "$SSH_KEY.pub")" --arg tag "$TAG" --arg name "$key_name" \
        '{name: $name, public_key: $k, labels: {($tag): "true"}}')" 2>/dev/null | jq -r '.ssh_key.id') \
      || key_id=$(api GET "/ssh_keys?fingerprint=$fingerprint" | jq -r '.ssh_keys[0].id // empty')
    [[ -n "$key_id" ]] || die "couldn't add the SSH key to the Hetzner project"
  fi
  # (On a line of its own, so a failure stops the test before a server is created.)
  user_data=$(launcher)
  body=$(jq -nc --arg location "$REGION" --arg name "$NAME" --arg tag "$TAG" --argjson key "$key_id" \
      --arg type "${PIAB_HETZNER_SERVER_TYPE:-cpx02}" --arg ubuntu "$UBUNTU" --arg ud "$user_data" \
      '{name: $name, server_type: $type, image: ("ubuntu-" + $ubuntu), location: $location,
        ssh_keys: [$key], user_data: $ud, labels: {($tag): "true"},
        public_net: {enable_ipv4: true, enable_ipv6: true}}')
  created=$(api POST /servers "$body")
  SERVER_ID=$(jq -r '.server.id' <<<"$created")
  IP=$(jq -r '.server.public_net.ipv4.ip' <<<"$created")
elif [[ "$PROVIDER" == digitalocean ]]; then
  REGION=${PIAB_TEST_REGION:-nyc3}
  fingerprint=$(ssh-keygen -l -E md5 -f "$SSH_KEY.pub" | awk '{print $2}' | sed 's/^MD5://')
  if ! api GET "/account/keys/$fingerprint" >/dev/null 2>&1; then
    say "Adding the test SSH key to DigitalOcean"
    api POST /account/keys "$(jq -nc --arg k "$(cat "$SSH_KEY.pub")" '{name: "piab-test", public_key: $k}')" >/dev/null
  fi
  user_data=$(launcher)
  body=$(jq -nc --arg region "$REGION" --arg name "$NAME" --arg tag "$TAG" --arg fp "$fingerprint" \
      --arg ud "$user_data" --arg ubuntu "$UBUNTU" --arg size "${PIAB_DO_SIZE:-s-1vcpu-1gb}" \
      '{name: $name, region: $region, size: $size, image: ("ubuntu-" + ($ubuntu | sub("\\."; "-")) + "-x64"),
        ssh_keys: [$fp], tags: [$tag], user_data: $ud}')
  SERVER_ID=$(api POST /droplets "$body" | jq -r '.droplet.id')
  deadline=$((SECONDS + 300))
  until [[ -n "$IP" ]]; do
    (( SECONDS < deadline )) || die "the Droplet got no public address within 5 minutes"
    sleep 5
    IP=$(api GET "/droplets/$SERVER_ID" | jq -r '.droplet.networks.v4[] | select(.type == "public") | .ip_address')
  done
else
  vpc=$(ec2 describe-vpcs --filters Name=is-default,Values=true | jq -r '.Vpcs[0].VpcId // empty')
  [[ -n "$vpc" ]] || die "no default VPC in $AWS_DEFAULT_REGION"
  ami=$(ec2 describe-images --owners 099720109477 \
      --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-$UBUNTU_CODENAME-$UBUNTU-amd64-server-*" \
                Name=state,Values=available Name=virtualization-type,Values=hvm \
    | jq -r '.Images | sort_by(.CreationDate) | last | .ImageId // empty')
  [[ -n "$ami" ]] || die "couldn't find the Ubuntu $UBUNTU AMI in $AWS_DEFAULT_REGION"
  # One key pair per computer, named after its key's fingerprint (as on Hetzner).
  key_name="$TAG-$(ssh-keygen -l -E md5 -f "$SSH_KEY.pub" | awk '{print $2}' | sed 's/^MD5://' | tr -d : | cut -c1-8)"
  local_fp=$(ssh-keygen -l -E sha256 -f "$SSH_KEY.pub" | awk '{print $2}' | sed 's/^SHA256://')
  if aws_fp=$(ec2 describe-key-pairs --key-names "$key_name" 2>/dev/null | jq -r '.KeyPairs[0].KeyFingerprint'); then
    # AWS pads the base64 SHA-256 fingerprint of an ed25519 key with "=".
    [[ "${aws_fp%%=*}" == "$local_fp" ]] \
      || die "AWS key pair $key_name doesn't match $SSH_KEY.pub; delete it in EC2 > Key pairs ($AWS_DEFAULT_REGION) and run again"
  else
    say "Adding the test SSH key to AWS as key pair $key_name"
    ec2 import-key-pair --key-name "$key_name" --public-key-material "fileb://$SSH_KEY.pub" \
      --tag-specifications "ResourceType=key-pair,Tags=[{Key=$TAG,Value=true}]" >/dev/null
  fi
  if (( CLOUDFORMATION )); then
    # As the Launch Stack button does, with this commit's template and script.
    git show "$SHA:src/aws/cloudformation.yaml" > "$WORK/cloudformation.yaml"
    jq -n --arg pw "$ADMIN_PASSWORD" --arg key "$key_name" --arg release "$SHA" \
        --arg type "${PIAB_AWS_INSTANCE_TYPE:-t3.small}" --arg addons "$ADDONS" --arg frontend "$FRONTEND_IMAGE" \
        --arg backend "$BACKEND_IMAGE" --arg reg_user "$REGISTRY_USER" --arg reg_token "$REGISTRY_TOKEN" --arg spamhaus "$SPAMHAUS_KEY" --arg lang "${SITE_LANGUAGE:-en}" --arg content "${STARTER_CONTENT:-yes}" --arg demo "$DEMO_USER" --arg demopw "$DEMO_PASSWORD_SET" --arg roles "$DEMO_ROLES" --arg notify "$NOTIFY_URL" \
        --arg smtp_host "$SMTP_HOST" --arg smtp_port "$SMTP_PORT" --arg smtp_user "$SMTP_USER" \
        --arg smtp_password "$SMTP_PASSWORD" --arg email_from "$EMAIL_FROM" --arg report_email "$MAIL_TO" \
        --arg log_server "$LOG_SERVER" --arg log_token "$LOG_TOKEN" --arg metrics_endpoint "$METRICS_ENDPOINT" \
        --arg metrics_user "$METRICS_USER" --arg metrics_token "$METRICS_TOKEN" --arg panel "$CONTROL_PANEL" \
      '{AdminPassword: $pw, KeyName: $key, Release: $release, InstanceType: $type, Addons: $addons,
        FrontendImage: $frontend, BackendImage: $backend, RegistryUser: $reg_user, RegistryToken: $reg_token, SiteLanguage: $lang, StarterContent: $content, DemoUser: $demo, DemoPassword: $demopw, DemoRoles: $roles, NotifyUrl: $notify,
        SmtpHost: $smtp_host, SmtpPort: $smtp_port, SmtpUser: $smtp_user, SmtpPassword: $smtp_password,
        EmailFrom: $email_from, ReportEmail: $report_email, SpamhausKey: $spamhaus,
        LogServer: $log_server, LogToken: $log_token, MetricsEndpoint: $metrics_endpoint,
        MetricsUser: $metrics_user, MetricsToken: $metrics_token,
        ControlPanel: (if $panel == "yes" then "yes" else "" end)}
       | to_entries | map(select(.value != "") | {ParameterKey: .key, ParameterValue: .value})' \
      > "$WORK/cloudformation-parameters.json"
    say "Creating stack $NAME from src/aws/cloudformation.yaml"
    aws cloudformation create-stack --stack-name "$NAME" --template-body "file://$WORK/cloudformation.yaml" \
        --parameters "file://$WORK/cloudformation-parameters.json" --tags "Key=$TAG,Value=true" >/dev/null \
      || { rm -f "$WORK/cloudformation-parameters.json"; die "couldn't create the stack"; }
    rm -f "$WORK/cloudformation-parameters.json"  # it has the passwords
    SERVER_ID=$NAME
    if ! aws cloudformation wait stack-create-complete --stack-name "$NAME"; then
      aws cloudformation describe-stack-events --stack-name "$NAME" --output json \
        | jq -r '.StackEvents[] | select(.ResourceStatus | test("FAILED")) | "  \(.LogicalResourceId): \(.ResourceStatusReason)"' >&2
      die "the stack wasn't created"
    fi
    IP=$(aws cloudformation describe-stacks --stack-name "$NAME" --output json \
      | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PublicIP") | .OutputValue')
    [[ -n "$IP" ]] || die "the stack has no PublicIP output"
  fi
fi
if [[ "$PROVIDER" == aws ]] && (( ! CLOUDFORMATION )); then
  sg=$(ec2 describe-security-groups --filters "Name=group-name,Values=$TAG" "Name=vpc-id,Values=$vpc" \
    | jq -r '.SecurityGroups[0].GroupId // empty')
  if [[ -z "$sg" ]]; then
    say "Creating security group $TAG (SSH, HTTP and HTTPS from anywhere)"
    sg=$(ec2 create-security-group --group-name "$TAG" --vpc-id "$vpc" \
        --description "Plone in a Box test servers: SSH, HTTP and HTTPS" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=$TAG,Value=true}]" | jq -r '.GroupId')
    ec2 authorize-security-group-ingress --group-id "$sg" --ip-permissions "$(jq -nc '[[22, 80, 443][]
        | {IpProtocol: "tcp", FromPort: ., ToPort: ., IpRanges: [{CidrIp: "0.0.0.0/0"}],
           Ipv6Ranges: [{CidrIpv6: "::/0"}]}]')" >/dev/null
  fi
  launcher > "$WORK/user-data.sh"
  SERVER_ID=$(ec2 run-instances --image-id "$ami" --instance-type "${PIAB_AWS_INSTANCE_TYPE:-t3.small}" \
      --key-name "$key_name" --security-group-ids "$sg" --user-data "file://$WORK/user-data.sh" \
      --block-device-mappings '[{"DeviceName": "/dev/sda1", "Ebs": {"VolumeSize": 20, "VolumeType": "gp3", "DeleteOnTermination": true}}]' \
      --metadata-options HttpTokens=required \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=$TAG,Value=true}]" \
                           "ResourceType=volume,Tags=[{Key=$TAG,Value=true}]" \
    | jq -r '.Instances[0].InstanceId')
  deadline=$((SECONDS + 300))
  until [[ -n "$IP" ]]; do
    (( SECONDS < deadline )) || die "the instance got no public address within 5 minutes"
    sleep 5
    IP=$(ec2 describe-instances --instance-ids "$SERVER_ID" \
      | jq -r '.Reservations[0].Instances[0].PublicIpAddress // empty')
  done
fi
echo "server: $SERVER_ID at $IP" >> "$WORK/notes.txt"
say "Created $NAME ($SERVER_ID) at $IP"
START=$SECONDS

# --- Helpers for the checks ----------------------------------------------------

SSH_OPTS=(-i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o LogLevel=ERROR
          -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$WORK/known_hosts")
# Linode and DigitalOcean log in as root; AWS as ubuntu, with sudo.
# Commands are expanded locally on purpose (they include values from here).
# shellcheck disable=SC2029
if [[ "$PROVIDER" == aws ]]; then
  SSH_USER=ubuntu SUDO=sudo
  rssh() { ssh "${SSH_OPTS[@]}" "$SSH_USER@$IP" "sudo bash -c $(printf '%q' "$*")"; }
else
  SSH_USER=root SUDO=""
  rssh() { ssh "${SSH_OPTS[@]}" "$SSH_USER@$IP" "$@"; }
fi
elapsed() { printf '%dm%02ds' $(( (SECONDS - START) / 60 )) $(( (SECONDS - START) % 60 )); }

# wait_until <description> <timeout seconds> <command...>
wait_until() {
  local what=$1 deadline=$((SECONDS + $2))
  shift 2
  until "$@" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      fail "$what (gave up after $(elapsed))"
      return 1
    fi
    sleep 10
  done
  pass "$what ($(elapsed))"
}

page() { curl -s -m 10 "$SITE/"; }
progress_page_up() { page | grep -q 'Plone in a Box'; }
setup_done() { rssh "grep -q '^\[plone-in-a-box\] Finished' /var/log/plone-in-a-box.log"; }
setup_failed() {
  page | grep -q "Setup didn't finish" \
    || rssh "grep -q '^\[plone-in-a-box\] Setup failed' /var/log/plone-in-a-box.log" 2>/dev/null
}
setup_done_or_failed() { setup_done || setup_failed; }
login() {
  curl -s -m 20 -X POST "$SITE/++api++/@login" -H 'Accept: application/json' \
      -H 'Content-Type: application/json' --data "$(jq -nc --arg p "$1" '{login: "admin", password: $p}')" \
    | jq -er '.token'
}
old_password_rejected() { ! login "$ADMIN_PASSWORD"; }
# The demo login: its password from the credentials file, and its roles.
demo_login() {
  curl -s -m 20 -X POST "$SITE/++api++/@login" -H 'Accept: application/json' \
      -H 'Content-Type: application/json' --data "$(jq -nc --arg u "$DEMO_USER" --arg p "$DEMO_PASSWORD" '{login: $u, password: $p}')" \
    | jq -er '.token'
}
demo_password_not_logged() { [[ -n "$DEMO_PASSWORD" ]] && ! grep -qF -- "$DEMO_PASSWORD" "$WORK/setup.log"; }
# Every expected role (separated by commas), and the credentials file names them.
demo_has_roles() {
  local token
  token=$(demo_login) || return 1
  curl -s -m 20 "$SITE/++api++/@users/$DEMO_USER" -H 'Accept: application/json' \
      -H "Authorization: Bearer $token" \
    | jq -e --arg r "$EXPECT_DEMO_ROLES" \
        '.roles as $have | [$r | split(",")[] | gsub("^ +| +$"; "") | select(. != "")] | all(. as $x | $have | index($x))' \
      >/dev/null
}
# With email set up: the demo login isn't a Site Administrator, and can't
# read Site Setup > Mail.
demo_not_site_admin() {
  local token
  token=$(demo_login) || return 1
  curl -s -m 20 "$SITE/++api++/@users/$DEMO_USER" -H 'Accept: application/json' \
      -H "Authorization: Bearer $token" | jq -e '.roles | index("Site Administrator") == null' >/dev/null
}
demo_cant_read_mail_settings() {
  local token out code
  token=$(demo_login) || return 1
  out=$(curl -s -m 20 -w '\n%{http_code}' "$SITE/++api++/@controlpanels/mail" -H 'Accept: application/json' \
      -H "Authorization: Bearer $token")
  code=${out##*$'\n'}
  [[ "$code" == 401 || "$code" == 403 ]] && [[ "$out" != *"$SMTP_PASSWORD"* ]]
}
# The add-on names without versions or extras, e.g. collective.easyform.
addon_names() { for a in ${1-$ADDONS}; do a=${a%%[[~=!<>]*}; echo "$a"; done; }
# Every add-on is offered in Site Setup > Add-ons (or is already activated).
addons_listed() {
  local token ids name
  token=$(login "$1") || return 1
  ids=$(curl -s -m 30 "$SITE/++api++/@addons" -H 'Accept: application/json' \
    -H "Authorization: Bearer $token" | jq -r '.items[].id') || return 1
  for name in $(addon_names); do grep -qx "$name" <<<"$ids" || return 1; done
}
addons_activate() {
  local token name
  token=$(login "$1") || return 1
  for name in $(addon_names); do
    curl -sf -m 120 -X POST "$SITE/++api++/@addons/$name/install" -H 'Accept: application/json' \
      -H "Authorization: Bearer $token" >/dev/null || return 1
  done
}
addons_active() {
  local token installed name list=${2-$ADDONS}
  token=$(login "$1") || return 1
  installed=$(curl -s -m 30 "$SITE/++api++/@addons" -H 'Accept: application/json' \
    -H "Authorization: Bearer $token" | jq -r '.items[] | select(.is_installed) | .id') || return 1
  for name in $(addon_names "$list"); do grep -qx "$name" <<<"$installed" || return 1; done
}
# The frontend image's labels, read on the server.
image_label() {
  rssh "docker image inspect -f '{{index .Config.Labels \"org.plone-in-a-box.$1\"}}' '$FRONTEND_IMAGE'" 2>/dev/null
}
frontend_runs() {
  [[ "$(rssh "docker compose --project-directory /opt/plone ps --format '{{.Image}}' frontend")" == "$1" ]]
}
# The site's language (the registry's default language) and its number of items.
site_language() {
  local token; token=$(login "$1") || return 1
  curl -s -m 20 "$SITE/++api++/@registry/plone.default_language" -H 'Accept: application/json' \
    -H "Authorization: Bearer $token" | jq -r .
}
site_items() {
  local token; token=$(login "$1") || return 1
  curl -s -m 20 "$SITE/++api++/" -H 'Accept: application/json' -H "Authorization: Bearer $token" | jq -r '.items | length'
}
backend_runs() {
  [[ "$(rssh "docker compose --project-directory /opt/plone ps --format '{{.Image}}' backend")" == "$1" ]]
}
behaviors_enabled() {
  local token data name
  token=$(login "$1") || return 1
  data=$(curl -s -m 30 "$SITE/++api++/@controlpanels/dexterity-types/Plone%20Site" \
    -H 'Accept: application/json' -H "Authorization: Bearer $token" | jq -c .data) || return 1
  for name in $2; do jq -e --arg n "$name" '.[$n] == true' <<<"$data" >/dev/null || return 1; done
}
site_is_plone() { ! page | grep -q 'Plone in a Box</title>' && curl -sf -m 10 "$SITE/++api++/" | jq -e '."@id"' >/dev/null; }
port_closed() {
  local timeout=(-w 5)
  # macOS nc needs -G for the connection timeout.
  if nc -h 2>&1 | grep -qE '^[[:space:]]+-G'; then timeout+=(-G 5); fi
  if nc -z "${timeout[@]}" "$IP" "$1" 2>/dev/null; then return 1; fi
}
count_in_log() { rssh "grep -c '^\[plone-in-a-box\] $1' /var/log/plone-in-a-box.log || true"; }

# --- Setup -------------------------------------------------------------------------

SITE="http://$IP"
wait_until "progress page is up" 600 progress_page_up || true
if ! wait_until "setup finished or failed" 2400 setup_done_or_failed; then
  rssh 'cat /var/log/plone-in-a-box.log' > "$WORK/setup.log" 2>/dev/null \
    && say "Setup log so far saved to $WORK/setup.log; last lines:" && tail -5 "$WORK/setup.log" | sed 's/^/      /'
  exit 1
fi
rssh 'cat /var/log/plone-in-a-box.log' > "$WORK/setup.log" 2>/dev/null || true
if setup_failed; then
  fail "setup failed; log saved to $WORK/setup.log"
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | tail -5
  exit 1
fi
pass "setup finished: $(grep '^\[plone-in-a-box\] Finished' "$WORK/setup.log")"
# The address setup gives: https://<IP> once the IP address certificate is in.
SITE=$(rssh 'cat /var/lib/plone-in-a-box/site-url' 2>/dev/null || echo "http://$IP")
say "      site address: $SITE"
# Test servers have no domain name, so setup gets a certificate for the IP address.
if true; then
  check "the site is on HTTPS at its IP address" test "$SITE" = "https://$IP"
  check "the HTTPS certificate is for $IP and trusted" bash -c "curl -fsS -m 20 -o /dev/null 'https://$IP/'"
  check "HTTP redirects to HTTPS" bash -c "[[ \"\$(curl -s -m 20 -o /dev/null -w '%{http_code} %{redirect_url}' 'http://$IP/foo?x=1')\" == '301 https://$IP/foo?x=1' ]]"
  check "Let's Encrypt's checks still reach port 80" bash -c "[[ \"\$(curl -s -m 20 -o /dev/null -w '%{http_code}' 'http://$IP/.well-known/acme-challenge/test')\" == 404 ]]"
  check "the certificate renews by itself (plone-https-ip.timer)" rssh 'systemctl is-enabled --quiet plone-https-ip.timer'
  rssh "openssl x509 -in /etc/letsencrypt/live/plone-ip/fullchain.pem -noout -issuer -enddate" 2>/dev/null | sed 's/^/      /' || true
fi
grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'swap\|restart\|continuing' | sed 's/^/      /' || true

wait_until "the site is Plone, not the progress page" 300 site_is_plone || true

# --- Admin password ---------------------------------------------------------------

if (( GENERATED )); then
  ADMIN_PASSWORD=$(rssh "awk '/^Password:/ {print \$2}' /root/plone-credentials.txt" 2>/dev/null || true)
  check "generated password is in /root/plone-credentials.txt" test -n "$ADMIN_PASSWORD"
  echo "generated admin password: $ADMIN_PASSWORD" >> "$WORK/notes.txt"
else
  check "credentials file doesn't contain the chosen password" \
    rssh "! grep -qF -- '$ADMIN_PASSWORD' /root/plone-credentials.txt"
fi
check "admin can log in" login "$ADMIN_PASSWORD"

if token=$(login "$ADMIN_PASSWORD"); then
  curl -s -m 20 "$SITE/++api++/@system" -H 'Accept: application/json' -H "Authorization: Bearer $token" \
    | jq -r '"      Plone \(.plone_version), plone.restapi \(.plone_restapi_version), Zope \(.zope_version), Python \(.python_version | split(" ")[0]), Pillow \(.pil_version)"' \
    2>/dev/null || true
fi

NEW_PASSWORD=$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-20)
echo "password after plone-reset-admin-password: $NEW_PASSWORD" >> "$WORK/notes.txt"
reset_output=$(printf '%s\n%s\n' "$NEW_PASSWORD" "$NEW_PASSWORD" \
  | ssh -tt "${SSH_OPTS[@]}" "$SSH_USER@$IP" $SUDO plone-reset-admin-password 2>&1 || true)
check "plone-reset-admin-password reports success" grep -q 'has been changed' <<<"$reset_output"
check "the new password works" login "$NEW_PASSWORD"
check "the old password no longer works" old_password_rejected

# --- Add-ons -------------------------------------------------------------------------

if (( ADDONS_SKIPPED )); then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'add-ons' | sed 's/^/      /' || true
  check "setup log says the add-ons were left out" \
    grep -qE "^\[plone-in-a-box\] (Not installing the backend add-ons|The backend add-ons couldn't be installed)" "$WORK/setup.log"
  check "credentials file says the add-ons weren't installed" \
    rssh "grep -qE 'add-ons .* (were not|couldn.t be) installed' /root/plone-credentials.txt"
  check "no add-ons are configured in /opt/plone/.env" rssh "grep -qx \"ADDONS=''\" /opt/plone/.env"
  check "the backend container has no add-ons" \
    rssh "test -z \"\$(docker compose --project-directory /opt/plone exec -T backend printenv ADDONS)\""
elif [[ -n "$ADDONS" ]]; then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'add-ons' | sed 's/^/      /' || true
  check "add-ons are offered in Site Setup > Add-ons" addons_listed "$NEW_PASSWORD"
  check "add-ons can be activated" addons_activate "$NEW_PASSWORD"
  check "add-ons are active" addons_active "$NEW_PASSWORD"
fi

# --- Frontend image ------------------------------------------------------------------

IMAGE_ADDONS="" IMAGE_BEHAVIORS=""
if [[ -n "$SITE_LANGUAGE" ]]; then
  check "the site's language is $SITE_LANGUAGE" test "$(site_language "$NEW_PASSWORD")" = "$SITE_LANGUAGE"
  check "credentials file names the language" rssh "grep -q '^Language:  $SITE_LANGUAGE' /root/plone-credentials.txt"
fi
if (( NO_STARTER )); then
  say "      items at the site root: $(site_items "$NEW_PASSWORD")"
  check "the site was created without starter content" test "$(site_items "$NEW_PASSWORD")" = 0
fi
if [[ -n "$REGISTRY_USER" ]]; then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'registry\|logged in to\|logging in to' | sed 's/^/      /' || true
  check "setup logged in to the registry as $REGISTRY_USER" rssh "grep -qF 'Registry:  logged in to' /root/plone-credentials.txt"
  check "Docker keeps the registry login for updates" rssh "test -s /root/.docker/config.json && grep -q '\"auths\"' /root/.docker/config.json"
  check "the registry token isn't in the setup log or credentials file" \
    rssh "! grep -qF -- $(printf '%q' "$REGISTRY_TOKEN") /var/log/plone-in-a-box.log /root/plone-credentials.txt"
fi
if (( BACKEND_FALLBACK )); then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'backend image' | sed 's/^/      /' || true
  check "the backend runs the official Plone image" rssh \
    "docker compose --project-directory /opt/plone ps --format '{{.Image}}' backend | grep -q '^plone/plone-backend:'"
  check "credentials file says why" rssh "grep -qi 'backend image .* official Plone backend' /root/plone-credentials.txt"
  check "no backend image is configured in /opt/plone/.env" rssh "grep -qx \"BACKEND_IMAGE=''\" /opt/plone/.env"
elif [[ -n "$BACKEND_IMAGE" ]]; then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'backend image' | sed 's/^/      /' || true
  check "the backend runs $BACKEND_IMAGE" backend_runs "$BACKEND_IMAGE"
  check "credentials file names the backend image" rssh "grep -qF 'Backend image: $BACKEND_IMAGE' /root/plone-credentials.txt"
fi
if (( FRONTEND_FALLBACK )); then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'frontend' | sed 's/^/      /' || true
  check "the frontend runs the standard Volto image" rssh \
    "docker compose --project-directory /opt/plone ps --format '{{.Image}}' frontend | grep -q '^plone/plone-frontend:'"
  check "credentials file says why" rssh "grep -qi 'frontend image .* standard Volto image' /root/plone-credentials.txt"
  check "no frontend image is configured in /opt/plone/.env" rssh "grep -qx \"FRONTEND_IMAGE=''\" /opt/plone/.env"
elif [[ -n "$FRONTEND_IMAGE" ]]; then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'frontend' | sed 's/^/      /' || true
  check "the frontend runs $FRONTEND_IMAGE" frontend_runs "$FRONTEND_IMAGE"
  IMAGE_ADDONS=$(image_label backend-addons || true)
  IMAGE_BEHAVIORS=$(image_label site-behaviors || true)
  say "      image labels: add-ons '${IMAGE_ADDONS}', behaviors '${IMAGE_BEHAVIORS}'"
  if [[ -n "$IMAGE_ADDONS" ]]; then
    check "the image's backend add-ons are active" addons_active "$NEW_PASSWORD" "$IMAGE_ADDONS"
  fi
  if [[ -n "$IMAGE_BEHAVIORS" ]]; then
    check "the image's site behaviors are enabled" behaviors_enabled "$NEW_PASSWORD" "$IMAGE_BEHAVIORS"
  fi
fi

# --- Demo login ----------------------------------------------------------------------

if [[ -n "$DEMO_USER" ]]; then
  grep '^\[plone-in-a-box\]' "$WORK/setup.log" | grep -i 'demo login' | sed 's/^/      /' || true
  if [[ -n "$DEMO_PASSWORD_SET" ]]; then
    DEMO_PASSWORD=$DEMO_PASSWORD_SET
    check "credentials file doesn't contain the demo password chosen" \
      rssh "grep -q '^Demo login: $DEMO_USER / (the password you entered' /root/plone-credentials.txt && ! grep -qF -- '$DEMO_PASSWORD' /root/plone-credentials.txt"
  else
    DEMO_PASSWORD=$(rssh "awk '/^Demo login:/ {print \$5}' /root/plone-credentials.txt" 2>/dev/null || true)
    check "credentials file gives the demo login's password" test -n "$DEMO_PASSWORD"
  fi
  echo "demo login: $DEMO_USER / $DEMO_PASSWORD" >> "$WORK/notes.txt"
  check "setup log doesn't contain the demo password" demo_password_not_logged
  check "the demo login can log in" demo_login
  check "the demo login has the roles ${EXPECT_DEMO_ROLES}" demo_has_roles
  if [[ -n "$MAIL_TO" ]]; then
    check "with email set up, the demo login isn't a Site Administrator" demo_not_site_admin
    check "the demo login can't read Site Setup > Mail" demo_cant_read_mail_settings
  fi
fi

# --- Network -------------------------------------------------------------------------

for port in 5432 8080 3000; do
  check "port $port is closed from outside" port_closed "$port"
done

# nginx: security headers everywhere (pages, the REST API, static files), no
# version number, and compressed JavaScript.
headers() { curl -s -m 20 -o /dev/null -D - -H 'Accept-Encoding: gzip' "$@" | tr -d '\r'; }
has_security_headers() {
  local h
  h=$(headers "$@")
  grep -qix 'x-frame-options: SAMEORIGIN' <<<"$h" && grep -qix 'x-content-type-options: nosniff' <<<"$h" \
    && grep -qix 'referrer-policy: strict-origin-when-cross-origin' <<<"$h" \
    && grep -qix "content-security-policy: frame-ancestors 'self'; base-uri 'self'; object-src 'none'" <<<"$h" \
    && grep -qix 'permissions-policy: camera=(), microphone=(), payment=(), usb=()' <<<"$h" \
    && ! grep -qi '^x-powered-by:' <<<"$h" \
    && [[ $(grep -ci '^x-frame-options:' <<<"$h") == 1 ]]
}
js=$(curl -s -m 20 "$SITE/" | grep -oE '/(static/js|assets)/[^"]*\.js' | head -n 1)
check "security headers on pages" has_security_headers "$SITE/"
check "security headers on the REST API" has_security_headers -H 'Accept: application/json' "$SITE/++api++/"
check "security headers and compression on JavaScript ($js)" \
  bash -c "h=\$(curl -s -m 20 -o /dev/null -D - -H 'Accept-Encoding: gzip' '$SITE$js' | tr -d '\r'); grep -qix 'x-content-type-options: nosniff' <<<\"\$h\" && grep -qix 'content-encoding: gzip' <<<\"\$h\""
check "nginx doesn't show its version" bash -c "! curl -s -m 20 -o /dev/null -D - 'http://$IP/' | grep -i '^server:' | grep -q '[0-9]'"
# The blocklist helper, with each list's own test entries: listed where the
# list answers this provider's DNS resolver, unchecked where it doesn't.
bl=$(rssh '/usr/local/lib/plone-in-a-box/blocklists --ip 127.0.0.2 dbltest.com test.surbl.org' || true)
printf '%s\n' "$bl" | sed 's/^/      /'
# shellcheck disable=SC2016 # expanded by the inner bash
if [[ -n "$SPAMHAUS_KEY" ]]; then
  check "the blocklist lookup asks Spamhaus through the DQS key, and gives its test entries as listed" \
    bash -c 'for l in zen.dq.spamhaus.net dbl.dq.spamhaus.net; do grep -qE "^LISTED [^ ]+ $l " <<<"$1" || exit 1; done' _ "$bl"
  check "the Spamhaus key is only readable by root" rssh "test \"\$(stat -c %a /var/lib/plone-in-a-box/spamhaus-key)\" = 600"
  check "the blocklist output doesn't show the Spamhaus key" bash -c '! grep -qF -- "$1" <<<"$2"' _ "$SPAMHAUS_KEY" "$bl"
  check "the Spamhaus key isn't in the setup log or credentials file" \
    rssh "! grep -qF -- $(printf '%q' "$SPAMHAUS_KEY") /var/log/plone-in-a-box.log /root/plone-credentials.txt"
else
  check "the blocklist lookup gives every list's test entry as listed or unchecked" \
    bash -c 'for l in zen.spamhaus.org bl.spamcop.net dbl.spamhaus.org multi.surbl.org; do grep -qE "^(LISTED [^ ]+|UNCHECKED) $l( |\$)" <<<"$1" || exit 1; done' _ "$bl"
fi
check "setup looked up the site in the blocklists" rssh "grep -qiE 'blocklist' /var/log/plone-in-a-box.log"
if [[ -n "$LOG_SERVER" ]]; then
  check "the logs go to the log server from the form (plone-syslog is on)" rssh "plone-syslog status | grep -q '^On: .*$LOG_SERVER'"
  check "the credentials file says where the logs go" rssh "grep -q '^Logs: .*also sent to' /root/plone-credentials.txt"
fi
if [[ -n "$METRICS_ENDPOINT" ]]; then
  check "the numbers go to the OpenTelemetry service from the form (plone-otel is on)" rssh "plone-otel status | grep -q '^On:'"
  check "the credentials file says where the numbers go" rssh "grep -q '^Graphs: .*numbers sent to' /root/plone-credentials.txt"
fi
for secret in "$LOG_TOKEN" "$METRICS_TOKEN"; do
  [[ -n "$secret" ]] || continue
  check "a log or graphs token isn't in the setup log or credentials file" \
    rssh "! grep -qF -- $(printf '%q' "$secret") /var/log/plone-in-a-box.log /root/plone-credentials.txt"
done

# --- Control panel ---------------------------------------------------------------------

if (( PANEL )); then
  # Turned on by setup (CONTROL_PANEL=yes), on port 8443 of the site's address.
  panel_line=$(rssh "grep '^Control panel' /root/plone-credentials.txt" 2>/dev/null)
  panel_pw=$(sed -n 's#.*, login box / \([A-Za-z0-9]*\)$#\1#p' <<<"$panel_line")
  PANEL_URL="https://$IP:8443"
  check "setup turned on the control panel (credentials file)" grep -qF "Control panel (preview): $PANEL_URL, login box / " <<<"$panel_line"
  check "setup gave the control panel a password" test -n "$panel_pw"
  check "the control panel asks for the login" bash -c "[[ \$(curl -s -m 20 -o /dev/null -w '%{http_code}' '$PANEL_URL/') == 401 ]]"
  check "the control panel refuses a wrong password" bash -c "[[ \$(curl -s -m 20 -o /dev/null -w '%{http_code}' -u box:wrong-password '$PANEL_URL/') == 401 ]]"
  check "the control panel's page opens with the password" bash -c "curl -s -m 20 -u 'box:$panel_pw' '$PANEL_URL/' | grep -q 'panel.js'"
  check "the control panel shows the status" bash -c "curl -s -m 60 -u 'box:$panel_pw' '$PANEL_URL/api/status' | python3 -c 'import json, sys; assert json.load(sys.stdin)[\"site\"][\"ok\"]'"
  check "the control panel's buttons refuse a request from another site" bash -c "[[ \$(curl -s -m 20 -o /dev/null -w '%{http_code}' -u 'box:$panel_pw' -X POST -H 'X-Plone-Panel: 1' -H 'Origin: https://example.org' '$PANEL_URL/api/do/backup') == 403 ]]"
  check "the control panel only does what its buttons do" bash -c "[[ \$(curl -s -m 20 -o /dev/null -w '%{http_code}' -u 'box:$panel_pw' -X POST -H 'X-Plone-Panel: 1' -H 'Origin: $PANEL_URL' '$PANEL_URL/api/do/plone-panel-off') == 404 ]]"
  check "the control panel's Back up now starts a backup" bash -c "curl -s -m 60 -u 'box:$panel_pw' -X POST -H 'X-Plone-Panel: 1' -H 'Origin: $PANEL_URL' '$PANEL_URL/api/do/backup' | grep -q 'backup is running'"
  check "the control panel's buttons work at most once a minute" bash -c "[[ \$(curl -s -m 60 -o /dev/null -w '%{http_code}' -u 'box:$panel_pw' -X POST -H 'X-Plone-Panel: 1' -H 'Origin: $PANEL_URL' '$PANEL_URL/api/do/backup') == 429 ]]"
  if [[ -n "$DEMO_USER" ]]; then
    demo_out=$(curl -s -m 280 -u "box:$panel_pw" -X POST -H 'X-Plone-Panel: 1' -H "Origin: $PANEL_URL" "$PANEL_URL/api/do/demo-password")
    demo_new=$(python3 -c 'import json, sys; m = json.load(sys.stdin)["message"]; print(m.rsplit(": ", 1)[1] if "has this password: " in m else "")' <<<"$demo_out" 2>/dev/null)
    check "the control panel makes a new demo password" test -n "$demo_new"
    [[ -z "$demo_new" ]] || DEMO_PASSWORD=$demo_new  # the later checks use the new one
    check "the new demo password logs in" demo_login
    check "the credentials file has the new demo password" rssh "grep -q '^Demo login: $DEMO_USER / $demo_new' /root/plone-credentials.txt"
  fi
  check "the control panel follows the backup" bash -c "curl -s -m 20 -u 'box:$panel_pw' '$PANEL_URL/api/job/backup' | grep -q '\"state\"'"
  check "the control panel's program can't change the server" rssh "p=\$(systemctl show -p User,NoNewPrivileges,ProtectSystem plone-panel.service); grep -qx User=plone-panel <<<\"\$p\" && grep -qx NoNewPrivileges=yes <<<\"\$p\" && grep -qx ProtectSystem=strict <<<\"\$p\""
  check "only the control panel's program can ask root" rssh "! sudo -u nobody bash -c 'echo status | nc -U -q1 /run/plone-panel/helper.sock' 2>/dev/null | grep -q site"
  check "repeated failed logins to the control panel are blocked (fail2ban)" rssh "fail2ban-client status nginx-http-auth | grep -q 'Total failed:[[:space:]]*[1-9]'"
  check "the control panel's program (port 8092) is closed from outside" port_closed 8092
  check "the site still works with the control panel on" bash -c "[[ \$(curl -s -m 20 -o /dev/null -w '%{http_code}' '$SITE/') == 200 ]]"
  # Only in the credentials file, like the admin password.
  check "the control panel's password isn't logged or kept elsewhere in plain text" \
    rssh "! grep -rqF -- $(printf '%q' "${panel_pw:-none}") /var/log/plone-in-a-box.log /var/log/plone-panel.log /etc/nginx"
  # Behind Cloudflare, port 8443 is for Cloudflare only (a stand-in list
  # here: turning Cloudflare on needs a domain pointing at it).
  rssh "printf '173.245.48.0/20\n' > /var/lib/plone-in-a-box/cloudflare-ranges && plone-cloudflare panel" >/dev/null 2>&1
  check "behind Cloudflare, the control panel's port is for Cloudflare only" \
    rssh "ufw status | grep -q '^8443/tcp .*ALLOW.*173.245.48.0/20' && ! ufw status | grep -qE '^8443/tcp +ALLOW +Anywhere'"
  check "behind Cloudflare, port 8443 is closed to everyone else" port_closed 8443
  rssh "rm -f /var/lib/plone-in-a-box/cloudflare-ranges && plone-cloudflare panel" >/dev/null 2>&1
  check "without Cloudflare, the control panel's port is open again" \
    rssh "ufw status | grep -qE '^8443/tcp +ALLOW +Anywhere' && ! ufw status | grep -q 173.245.48.0/20"
  rssh "plone-panel off" >/dev/null 2>&1
  check "plone-panel off closes port 8443" port_closed 8443
  check "plone-panel off removes the password" rssh "! test -e /etc/nginx/plone-panel.htpasswd"
fi

# --- Server state ---------------------------------------------------------------------

mem=$(rssh "awk '/MemTotal|SwapTotal/ {s += \$2} END {print s}' /proc/meminfo")
rssh 'free -m' | sed 's/^/      /'
check "memory plus swap is at least 3 GB" test "$mem" -ge 3000000
check "resume files are gone" rssh '! test -e /root/.plone-in-a-box-resume && ! test -e /etc/systemd/system/plone-in-a-box-resume.service'
if rssh 'test -e /var/run/reboot-required'; then
  say "NOTE  /var/run/reboot-required exists (updates released during setup can cause this)"
else
  pass "no restart required"
fi

# --- Updates --------------------------------------------------------------------------

# plone-update prints to the log and to us; keep its output with the notes.
run_update() {  # run_update <log name> [environment]
  local status=0
  rssh "${2:-} plone-update" > "$WORK/$1" 2>&1 || status=$?
  grep -E '\] (Up to date|Updated|Update failed|Not updated|Skipped|Backing up)' "$WORK/$1" | sed 's/^/      /' || true
  return "$status"
}
backend_image() {
  rssh "docker inspect -f '{{.Image}}' \$(docker compose --project-directory /opt/plone ps -q backend)"
}
motd_says() { rssh "/etc/update-motd.d/90-plone-in-a-box" | grep -q "$1"; }
# A notice with this text in its title arrived at the ntfy topic.
notice_arrived() {
  curl -s -m 30 "$NOTIFY_URL/json?poll=1&since=all" | jq -r 'select(.event == "message") | .title' | grep -q "$1"
}

if [[ -n "$NOTIFY_URL" ]]; then
  check "the notice that the site is ready arrived" notice_arrived 'Plone in a Box is ready'
  check "credentials file mentions the notices" rssh "grep -q '^Notices: .*first notice was sent' /root/plone-credentials.txt"
  check "only root can read the notification URL" test "$(rssh 'stat -c %a /var/lib/plone-in-a-box/notify-url')" = 600
  check "the setup log doesn't contain the notification URL" rssh "! grep -qF '$NOTIFY_URL' /var/log/plone-in-a-box.log"
fi

if [[ -n "$MAIL_TO" ]]; then
  check "setup sent a test email" rssh "grep -q 'Sent a test email to $MAIL_TO' /var/log/plone-in-a-box.log"
  check "credentials file mentions the email settings" \
    rssh "grep -q '^Email: .*a test email went to $MAIL_TO' /root/plone-credentials.txt"
  check "update reports go to the address for reports" test "$(rssh 'cat /var/lib/plone-in-a-box/report-email')" = "$MAIL_TO"
  check "the SMTP password isn't in the setup log or the credentials file" \
    rssh "! grep -qF -- $(printf '%q' "$SMTP_PASSWORD") /var/log/plone-in-a-box.log /root/plone-credentials.txt"
fi

check "nightly backups are on (plone-backup.timer)" rssh \
  'systemctl is-enabled --quiet plone-backup.timer && systemctl is-active --quiet plone-backup.timer'
# Every container: Docker's own files, at most 30 MB each, or journald (which
# has its own limit) when the logs go to a log server too.
journald_ok=""
[[ -z "$LOG_SERVER" ]] || journald_ok="|journald "
check "container logs are limited in size" rssh \
  "out=\$(docker inspect -f '{{.HostConfig.LogConfig.Type}} {{.HostConfig.LogConfig.Config}}' \$(docker compose --project-directory /opt/plone ps -q)); [ \$(wc -l <<<\"\$out\") -ge 3 ] && ! grep -vE '^(json-file .*max-size:10m$journald_ok)' <<<\"\$out\""
check "plone-backup backs up and packs the database" rssh \
  'rm -f /var/lib/plone-in-a-box/last-pack && plone-backup pack && test -s /var/lib/plone-in-a-box/last-pack && find /var/backups/plone -name "plone-*.sql.gz" -mmin -10 | grep -q . && grep -q "^\[.*\] Packed$" /var/log/plone-backup.log'
rssh 'tail -n 4 /var/log/plone-backup.log' 2>/dev/null | sed 's/^/      /'
# plone-restore: a page deleted after a backup comes back when that backup is
# restored, and a damaged backup file is refused without touching the site.
restore_page() {  # restore_page create|delete|exists
  local token; token=$(login "$NEW_PASSWORD") || return 1
  case $1 in
    create) curl -s -m 30 -X POST "$SITE/++api++/" -H 'Accept: application/json' -H 'Content-Type: application/json' \
              -H "Authorization: Bearer $token" --data '{"@type": "Document", "id": "restore-test", "title": "Restore test"}' \
              | jq -e '.id == "restore-test"' >/dev/null ;;
    delete) curl -s -m 30 -o /dev/null -w '%{http_code}' -X DELETE "$SITE/++api++/restore-test" \
              -H 'Accept: application/json' -H "Authorization: Bearer $token" | grep -qx 204 ;;
    exists) curl -s -m 30 "$SITE/++api++/restore-test" -H 'Accept: application/json' -H "Authorization: Bearer $token" \
              | jq -e '.title == "Restore test"' >/dev/null ;;
  esac
}
restore_page_gone() { ! restore_page exists; }
if check "a test page can be created" restore_page create \
   && check "plone-backup takes a backup with it" rssh 'plone-backup' \
   && check "the test page can be deleted" restore_page delete \
   && check "the test page is gone" restore_page_gone; then
  # shellcheck disable=SC2016  # expanded on the server
  check "plone-restore refuses a damaged backup" rssh \
    'head -c 2000 "$(ls -1t /var/backups/plone/plone-*.sql.gz | head -n 1)" > /tmp/damaged.sql.gz; ! plone-restore /tmp/damaged.sql.gz --yes'
  # shellcheck disable=SC2016  # expanded on the server
  check "plone-restore restores the newest backup" rssh \
    'plone-restore "$(ls -1t /var/backups/plone/plone-*.sql.gz | head -n 1)" --yes'
  rssh 'tail -n 3 /var/log/plone-restore.log' 2>/dev/null | sed 's/^/      /' || true
  check "the test page is back after the restore" restore_page exists
  check "the admin password still works after the restore" login "$NEW_PASSWORD"
  check "plone-restore kept a backup of the site as it was" rssh 'ls /var/backups/plone/before-restore-*.sql.gz'
fi
check "automatic updates are on (plone-update.timer)" rssh \
  'systemctl is-enabled --quiet plone-update.timer && systemctl is-active --quiet plone-update.timer'
check "credentials file mentions updates" rssh "grep -q '^Updates: .*automatically' /root/plone-credentials.txt"
run_update update-check.log || true
check "plone-update finds the site up to date" grep -q '\] Up to date' "$WORK/update-check.log"
check "the login message shows the last update" motd_says 'last update: .*Up to date'

if (( UPDATES )); then
  OLD_PLONE=${PIAB_TEST_OLD_PLONE:-6.2.2}
  current=$(rssh "sed -n 's/^PLONE_VERSION=//p' /opt/plone/.env")
  say "Putting the backend on Plone $OLD_PLONE, as if the server were behind"
  rssh "docker pull -q plone/plone-backend:$OLD_PLONE && docker tag plone/plone-backend:$OLD_PLONE plone/plone-backend:$current \
    && docker compose --project-directory /opt/plone up -d --wait backend" >/dev/null 2>&1 || true
  old_id=$(rssh "docker image inspect -f '{{.Id}}' plone/plone-backend:$OLD_PLONE")
  check "the backend runs Plone $OLD_PLONE" test "$(backend_image)" = "$old_id"
  wait_until "site works on Plone $OLD_PLONE" 300 login "$NEW_PASSWORD" || true

  status=0
  run_update update-rollback.log PLONE_UPDATE_HEALTH_TIMEOUT=5 || status=$?
  check "an update the site doesn't come back from is undone (exit 1)" test "$status" = 1
  check "after undoing it, the backend runs Plone $OLD_PLONE again" test "$(backend_image)" = "$old_id"
  wait_until "site works after the undone update" 300 login "$NEW_PASSWORD" || true
  check "the login message says it was undone" motd_says 'failed and was undone'

  run_update update-skip.log || true
  check "next time, the failed build is skipped" grep -q 'Skipped the new backend image' "$WORK/update-skip.log"
  check "the backend still runs Plone $OLD_PLONE" test "$(backend_image)" = "$old_id"

  rssh 'rm -f /var/lib/plone-in-a-box/failed-images'
  status=0
  run_update update.log || status=$?
  new_id=$(rssh "docker image inspect -f '{{.Id}}' plone/plone-backend:$current")
  check "plone-update installs the newer Plone (exit 0)" test "$status" = 0
  check "it reports the versions" grep -q "Updated: Plone $OLD_PLONE" "$WORK/update.log"
  if [[ -n "$MAIL_TO" ]]; then
    check "the update report was emailed" grep -q "Emailed this report to $MAIL_TO" "$WORK/update.log"
  fi
  check "the backend runs the newest plone/plone-backend:$current" test "$(backend_image)" = "$new_id" -a "$new_id" != "$old_id"
  # shellcheck disable=SC2016 # expanded on the server
  check "the database was backed up first" rssh \
    'gzip -t "$(ls -1t /var/backups/plone/plone-*.sql.gz | head -1)" && test -s "$(ls -1t /var/backups/plone/plone-*.sql.gz | head -1)"'
  wait_until "site works after the update" 300 login "$NEW_PASSWORD" || true
  check "the login message shows the update" motd_says 'last update: .*Updated'
  if [[ -n "$NOTIFY_URL" ]]; then
    check "the report about the undone update arrived" notice_arrived 'Update failed and was undone'
    check "the report about the update arrived" notice_arrived 'Plone in a Box: Updated'
  fi
fi

# --- Restarts -------------------------------------------------------------------------

if [[ -n "$METRICS_ENDPOINT" ]]; then
  # Shellcheck can't see the inner bash's variables.
  # shellcheck disable=SC2016
  check "numbers went out to the OpenTelemetry service, and none failed" \
    rssh 'out=$(plone-otel status); grep -qE "[1-9][0-9]* values sent, 0 failed" <<<"$out"'
fi

continued=$(count_in_log 'Continuing setup')
say "Recreating the backend container"
rssh 'docker compose --project-directory /opt/plone up -d --force-recreate backend' >/dev/null 2>&1 || true
wait_until "password still works after recreating the backend" 300 login "$NEW_PASSWORD" || true

say "Restarting the server"
rssh 'systemctl reboot' >/dev/null 2>&1 || true
sleep 30
wait_until "SSH is back after the restart" 600 rssh true || exit 1
wait_until "site works after the restart" 600 login "$NEW_PASSWORD" || true
check "setup didn't run again after the restart" test "$(count_in_log 'Continuing setup')" = "$continued"
check "setup finished exactly once" test "$(count_in_log 'Finished')" = 1
if [[ -n "$ADDONS" ]] && (( ! ADDONS_SKIPPED )); then
  check "add-ons are still active after the restarts" addons_active "$NEW_PASSWORD"
fi
if [[ -n "$BACKEND_IMAGE" ]] && (( ! BACKEND_FALLBACK )); then
  check "the backend still runs $BACKEND_IMAGE after the restarts" backend_runs "$BACKEND_IMAGE"
fi
if [[ -n "$FRONTEND_IMAGE" ]] && (( ! FRONTEND_FALLBACK )); then
  check "the frontend still runs $FRONTEND_IMAGE after the restarts" frontend_runs "$FRONTEND_IMAGE"
  if [[ -n "$IMAGE_ADDONS" ]]; then
    check "the image's backend add-ons are still active" addons_active "$NEW_PASSWORD" "$IMAGE_ADDONS"
  fi
fi

if [[ -n "$DEMO_USER" ]]; then
  check "the demo login still works after the restarts" demo_login
fi

# --- Result -------------------------------------------------------------------------------

if (( FAILURES )); then
  say "$FAILURES check(s) failed after $(elapsed). Details: $WORK"
  exit 1
fi
say "All checks passed after $(elapsed)"
