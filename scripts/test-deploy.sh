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

PROVIDER="" ACTION=deploy REF="" GENERATED=0 KEEP=0 ADDONS="" ADDONS_SKIPPED=0 FRONTEND_IMAGE="" FRONTEND_FALLBACK=0 UPDATES=0 NOTIFY_URL=""
SERVER_ID="" IP="" FAILURES=0

die() { echo "error: $*" >&2; exit 1; }
say() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
pass() { say "PASS  $*"; }
fail() { say "FAIL  $*"; FAILURES=$((FAILURES + 1)); }
check() { local what=$1; shift; if "$@" >/dev/null 2>&1; then pass "$what"; else fail "$what"; fi; }

usage() { sed -n '3,44p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

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
    --addons) ADDONS=${2:?--addons needs a value}; shift ;;
    --expect-addons-skipped) ADDONS_SKIPPED=1 ;;
    --frontend-image) FRONTEND_IMAGE=${2:?--frontend-image needs a value}; shift ;;
    --expect-frontend-fallback) FRONTEND_FALLBACK=1 ;;
    --updates) UPDATES=1 ;;
    --notify) NOTIFY_URL="https://ntfy.sh/piab-test-$(openssl rand -hex 12)" ;;
    --notify-url)
      NOTIFY_URL=${2:?--notify-url needs a value}; shift
      [[ "$NOTIFY_URL" == https://* ]] || NOTIFY_URL="https://$NOTIFY_URL"
      [[ "$NOTIFY_URL" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]\'\"]*)?$ ]] || die "--notify-url: not a URL" ;;
    *) usage ;;
  esac
  shift
done

tools="curl jq ssh git nc"
[[ "$PROVIDER" == aws ]] && tools+=" aws"
for tool in $tools; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

# --- API access ---------------------------------------------------------------

keychain_token() {
  command -v security >/dev/null && security find-generic-password -s "$1" -w 2>/dev/null
}
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
    ec2 describe-instances --filters "Name=tag:$TAG,Values=true" \
        Name=instance-state-name,Values=pending,running,stopping,stopped \
      | jq -r '.Reservations[].Instances[]
          | "\(.InstanceId)\t\(([.Tags[]? | select(.Key == "Name") | .Value][0]) // "-")\t\(.PublicIpAddress // "-")\t\(.State.Name)"'
  fi
}

delete_server() {
  if [[ "$PROVIDER" == linode ]]; then
    api DELETE "/linode/instances/$1" >/dev/null
  elif [[ "$PROVIDER" == hetzner ]]; then
    api DELETE "/servers/$1" >/dev/null
  elif [[ "$PROVIDER" == digitalocean ]]; then
    api DELETE "/droplets/$1" >/dev/null
  else
    ec2 terminate-instances --instance-ids "$1" >/dev/null
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
  [[ -z "$NOTIFY_URL" ]] || echo "notification URL: $NOTIFY_URL"
} > "$WORK/notes.txt"
[[ "$ADDONS" != *"'"* ]] || die "--addons can't contain a single quote"
(( ! ADDONS_SKIPPED )) || [[ -n "$ADDONS" ]] || die "--expect-addons-skipped needs --addons"
[[ "$FRONTEND_IMAGE" != *[\'\|\&]* ]] || die "--frontend-image can't contain ', | or &"
(( ! FRONTEND_FALLBACK )) || [[ -n "$FRONTEND_IMAGE" ]] || die "--expect-frontend-fallback needs --frontend-image"

cleanup_on_exit() {
  local status=$?
  if [[ -n "$SERVER_ID" ]]; then
    if (( KEEP )); then
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
    printf '%s\n' '#!/bin/bash' \
      "export ADMIN_PASSWORD='${ADMIN_PASSWORD:-CHANGE-ME}'" \
      ${ADDONS:+"export ADDONS='$ADDONS'"} \
      ${FRONTEND_IMAGE:+"export FRONTEND_IMAGE='$FRONTEND_IMAGE'"} \
      ${NOTIFY_URL:+"export NOTIFY_URL='$NOTIFY_URL'"} \
      "curl -fsSL --retry 10 --retry-all-errors -o /root/plone-in-a-box.sh https://raw.githubusercontent.com/tkimnguyen/plone-in-a-box/$SHA/src/StackScript && bash /root/plone-in-a-box.sh"
    return
  fi
  text=$(git show "$SHA:src/user-data.sh" \
    | sed -e "s/^export ADMIN_PASSWORD=''$/export ADMIN_PASSWORD='$ADMIN_PASSWORD'/" \
          -e "s|^export ADDONS=''$|export ADDONS='${ADDONS//&/\\&}'|" \
          -e "s|^export FRONTEND_IMAGE=''$|export FRONTEND_IMAGE='$FRONTEND_IMAGE'|" \
          -e "s|^export NOTIFY_URL=''$|export NOTIFY_URL='${NOTIFY_URL//&/\\&}'|" \
          -e "s/^PIAB_RELEASE='[^']*'$/PIAB_RELEASE='$SHA'/")
  grep -q "^PIAB_RELEASE='$SHA'$" <<<"$text" || die "couldn't set PIAB_RELEASE in src/user-data.sh"
  [[ -z "$ADDONS" ]] || grep -qF "export ADDONS='$ADDONS'" <<<"$text" || die "couldn't set ADDONS in src/user-data.sh"
  [[ -z "$FRONTEND_IMAGE" ]] || grep -qF "export FRONTEND_IMAGE='$FRONTEND_IMAGE'" <<<"$text" \
    || die "couldn't set FRONTEND_IMAGE in src/user-data.sh"
  [[ -z "$NOTIFY_URL" ]] || grep -qF "export NOTIFY_URL='$NOTIFY_URL'" <<<"$text" \
    || die "couldn't set NOTIFY_URL in src/user-data.sh"
  printf '%s\n' "$text"
}

# --- Create the server ------------------------------------------------------------

if [[ "$PROVIDER" == linode ]]; then
  REGION=${PIAB_TEST_REGION:-ca-central}
  STACKSCRIPT_ID=$(api GET /linode/stackscripts '' \
      "X-Filter: {\"label\": \"$LINODE_STACKSCRIPT_LABEL\", \"mine\": true}" | jq -r '.data[0].id // empty')
  [[ -n "$STACKSCRIPT_ID" ]] || die "no StackScript named $LINODE_STACKSCRIPT_LABEL in this Linode account"
  say "Updating StackScript $LINODE_STACKSCRIPT_LABEL ($STACKSCRIPT_ID) to src/StackScript from $REF"
  api PUT "/linode/stackscripts/$STACKSCRIPT_ID" "$(git show "$SHA:src/StackScript" | jq -Rs \
      --arg note "Test $REF ($(git rev-parse --short "$SHA"))" \
      '{script: ., rev_note: $note, images: ["linode/ubuntu24.04", "linode/ubuntu26.04"]}')" >/dev/null
  ROOT_PASS=$(openssl rand -base64 33 | tr -d '\n')
  body=$(jq -nc --arg region "$REGION" --arg label "$NAME" --arg tag "$TAG" --arg root "$ROOT_PASS" \
      --arg key "$(cat "$SSH_KEY.pub")" --argjson ss "$STACKSCRIPT_ID" --arg pw "$ADMIN_PASSWORD" \
      --arg fw "${PIAB_LINODE_FIREWALL_ID:-}" --arg ubuntu "$UBUNTU" --arg addons "$ADDONS" \
      --arg frontend "$FRONTEND_IMAGE" --arg type "${PIAB_LINODE_TYPE:-g6-nanode-1}" --arg notify "$NOTIFY_URL" \
      '{region: $region, type: $type, image: ("linode/ubuntu" + $ubuntu), label: $label, tags: [$tag],
        root_pass: $root, authorized_keys: [$key], stackscript_id: $ss,
        # Only the fields that are set, so older releases (without them) work too.
        stackscript_data: ({ADMIN_PASSWORD: $pw, ADDONS: $addons, FRONTEND_IMAGE: $frontend, NOTIFY_URL: $notify}
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
  body=$(jq -nc --arg location "$REGION" --arg name "$NAME" --arg tag "$TAG" --argjson key "$key_id" \
      --arg type "${PIAB_HETZNER_SERVER_TYPE:-cpx02}" --arg ubuntu "$UBUNTU" --arg ud "$(launcher)" \
      '{name: $name, server_type: $type, image: ("ubuntu-" + $ubuntu), location: $location,
        ssh_keys: [$key], user_data: $ud, labels: {($tag): "true"},
        public_net: {enable_ipv4: true, enable_ipv6: true}}')
  created=$(api POST /servers "$body")
  SERVER_ID=$(jq -r '.server.id' <<<"$created")
  IP=$(jq -r '.server.public_net.ipv4.ip' <<<"$created")
elif [[ "$PROVIDER" == digitalocean ]]; then
  REGION=${PIAB_TEST_REGION:-tor1}
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

page() { curl -s -m 10 "http://$IP/"; }
progress_page_up() { page | grep -q 'Plone in a Box'; }
setup_done() { rssh "grep -q '^\[plone-in-a-box\] Finished' /var/log/plone-in-a-box.log"; }
setup_failed() {
  page | grep -q "Setup didn't finish" \
    || rssh "grep -q '^\[plone-in-a-box\] Setup failed' /var/log/plone-in-a-box.log" 2>/dev/null
}
setup_done_or_failed() { setup_done || setup_failed; }
login() {
  curl -s -m 20 -X POST "http://$IP/++api++/@login" -H 'Accept: application/json' \
      -H 'Content-Type: application/json' --data "$(jq -nc --arg p "$1" '{login: "admin", password: $p}')" \
    | jq -er '.token'
}
old_password_rejected() { ! login "$ADMIN_PASSWORD"; }
# The add-on names without versions or extras, e.g. collective.easyform.
addon_names() { for a in ${1-$ADDONS}; do a=${a%%[[~=!<>]*}; echo "$a"; done; }
# Every add-on is offered in Site Setup > Add-ons (or is already activated).
addons_listed() {
  local token ids name
  token=$(login "$1") || return 1
  ids=$(curl -s -m 30 "http://$IP/++api++/@addons" -H 'Accept: application/json' \
    -H "Authorization: Bearer $token" | jq -r '.items[].id') || return 1
  for name in $(addon_names); do grep -qx "$name" <<<"$ids" || return 1; done
}
addons_activate() {
  local token name
  token=$(login "$1") || return 1
  for name in $(addon_names); do
    curl -sf -m 120 -X POST "http://$IP/++api++/@addons/$name/install" -H 'Accept: application/json' \
      -H "Authorization: Bearer $token" >/dev/null || return 1
  done
}
addons_active() {
  local token installed name list=${2-$ADDONS}
  token=$(login "$1") || return 1
  installed=$(curl -s -m 30 "http://$IP/++api++/@addons" -H 'Accept: application/json' \
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
behaviors_enabled() {
  local token data name
  token=$(login "$1") || return 1
  data=$(curl -s -m 30 "http://$IP/++api++/@controlpanels/dexterity-types/Plone%20Site" \
    -H 'Accept: application/json' -H "Authorization: Bearer $token" | jq -c .data) || return 1
  for name in $2; do jq -e --arg n "$name" '.[$n] == true' <<<"$data" >/dev/null || return 1; done
}
site_is_plone() { ! page | grep -q 'Plone in a Box</title>' && curl -sf -m 10 "http://$IP/++api++/" | jq -e '."@id"' >/dev/null; }
port_closed() {
  local timeout=(-w 5)
  # macOS nc needs -G for the connection timeout.
  if nc -h 2>&1 | grep -qE '^[[:space:]]+-G'; then timeout+=(-G 5); fi
  if nc -z "${timeout[@]}" "$IP" "$1" 2>/dev/null; then return 1; fi
}
count_in_log() { rssh "grep -c '^\[plone-in-a-box\] $1' /var/log/plone-in-a-box.log || true"; }

# --- Setup -------------------------------------------------------------------------

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
  curl -s -m 20 "http://$IP/++api++/@system" -H 'Accept: application/json' -H "Authorization: Bearer $token" \
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

# --- Network -------------------------------------------------------------------------

for port in 5432 8080 3000; do
  check "port $port is closed from outside" port_closed "$port"
done

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
if [[ -n "$FRONTEND_IMAGE" ]] && (( ! FRONTEND_FALLBACK )); then
  check "the frontend still runs $FRONTEND_IMAGE after the restarts" frontend_runs "$FRONTEND_IMAGE"
  if [[ -n "$IMAGE_ADDONS" ]]; then
    check "the image's backend add-ons are still active" addons_active "$NEW_PASSWORD" "$IMAGE_ADDONS"
  fi
fi

# --- Result -------------------------------------------------------------------------------

if (( FAILURES )); then
  say "$FAILURES check(s) failed after $(elapsed). Details: $WORK"
  exit 1
fi
say "All checks passed after $(elapsed)"
