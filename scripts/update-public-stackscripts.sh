#!/usr/bin/env bash
#
# Update the public Linode StackScripts to a release, through Linode's API:
#
#   931893   Plone in a Box (nguyen-plone)            src/StackScript
#   2318969  Juizi Dashboard "Try It" (nguyen-plone)  scripts/linode-addon-stackscript.sh
#   692002   the obsolete copy (tknguyen2)            scripts/linode-obsolete-stackscript.sh
#
# Usage:
#   scripts/update-public-stackscripts.sh VERSION            show what would change
#   scripts/update-public-stackscripts.sh VERSION --apply    change them
#
# Options:
#   --apply        update the StackScripts that differ (default: only show)
#   --only ID      only this StackScript (can be repeated)
#   --note TEXT    the revision note after "VERSION: " (default: "Plone in a Box VERSION")
#
# Each script is made from the release's tag, never from the working tree.
# Before changing one, it checks that the StackScript belongs to the expected
# account and is public; afterwards, that Linode has exactly the new script.
#
# Needs: curl, jq, git, and a Linode personal access token for each account,
# with only StackScripts Read/Write, in the macOS Keychain:
#   security add-generic-password -a "$USER" -s piab-linode-nguyen-plone -w
#   security add-generic-password -a "$USER" -s piab-linode-tknguyen2 -w
# (or NGUYEN_PLONE_TOKEN / TKNGUYEN2_TOKEN). See RELEASING.md.

set -euo pipefail

usage() { sed -n '3,27p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
die() { echo "error: $*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

# id | owner | keychain service | environment variable | how to make it
TARGETS=(
  "931893|nguyen-plone|piab-linode-nguyen-plone|NGUYEN_PLONE_TOKEN|main"
  "2318969|nguyen-plone|piab-linode-nguyen-plone|NGUYEN_PLONE_TOKEN|addon:Juizi Dashboard:ghcr.io/collective/plone-in-a-box-frontend:19-juizi-dashboard"
  "692002|tknguyen2|piab-linode-tknguyen2|TKNGUYEN2_TOKEN|obsolete"
)

VERSION="" APPLY=0 NOTE="" ONLY=()
while (( $# )); do
  case "$1" in
    --apply) APPLY=1 ;;
    --only) ONLY+=("${2:?--only needs an id}"); shift ;;
    --note) NOTE=${2:?--note needs text}; shift ;;
    -*) usage ;;
    *) [[ -z "$VERSION" ]] || usage; VERSION=$1 ;;
  esac
  shift
done
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || usage
NOTE="${VERSION}: ${NOTE:-Plone in a Box ${VERSION}}"
for tool in curl jq git; do command -v "$tool" >/dev/null || die "$tool is not installed"; done

here=$(cd "$(dirname "$0")/.." && pwd)
git -C "$here" fetch -q --tags origin 2>/dev/null || true
git -C "$here" rev-parse -q --verify "refs/tags/$VERSION" >/dev/null || die "there's no tag $VERSION"

WORK=$(mktemp -d)
cleanup() { git -C "$here" worktree remove --force "$WORK/tree" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
git -C "$here" worktree add -q --detach "$WORK/tree" "$VERSION"

token_for() {  # token_for SERVICE VARIABLE
  local value=${!2:-}
  if [[ -z "$value" ]] && command -v security >/dev/null; then
    value=$(security find-generic-password -s "$1" -w 2>/dev/null || true)
  fi
  # Reading a public StackScript needs no token; changing one does.
  [[ -n "$value" || "$APPLY" == 0 ]] || die "no Linode token: set $2 or add the Keychain item $1"
  printf '%s' "$value"
}

api() {  # api TOKEN METHOD PATH [JSON]
  local args=(-sS -m 30 -H 'Content-Type: application/json' -X "$2")
  [[ -z "$1" ]] || args+=(-H "Authorization: Bearer $1")
  [[ -z "${4:-}" ]] || args+=(--data "$4")
  curl "${args[@]}" "https://api.linode.com/v4$3"
}

make_script() {  # make_script HOW > script
  local how=$1
  case "$how" in
    main) cat "$WORK/tree/src/StackScript" ;;
    obsolete) cat "$WORK/tree/scripts/linode-obsolete-stackscript.sh" ;;
    addon:*)
      local rest=${how#addon:} name image
      name=${rest%%:*} image=${rest#*:}
      "$WORK/tree/scripts/linode-addon-stackscript.sh" --name "$name" --frontend-image "$image" ;;
    *) die "unknown kind $how" ;;
  esac
}

# The same text, ignoring trailing newlines (Linode may add or drop one).
same() { [[ "$(cat "$1")" == "$(cat "$2")" ]]; }
udf_names() { grep -o '^# <UDF name="[A-Z_]*"' | sed 's/.*name="//; s/"$//' | tr '\n' ' '; }

changed=0 failed=0
for target in "${TARGETS[@]}"; do
  IFS='|' read -r id owner service variable how <<<"$target"
  if (( ${#ONLY[@]} )) && [[ " ${ONLY[*]} " != *" $id "* ]]; then continue; fi
  say ""
  say "== $id ($owner)"
  token=$(token_for "$service" "$variable")
  current=$(api "$token" GET "/linode/stackscripts/$id")
  if ! jq -e '.id' >/dev/null 2>&1 <<<"$current"; then
    say "   can't read it: $(jq -r '.errors[0].reason // .' <<<"$current" 2>/dev/null)"; failed=1; continue
  fi
  label=$(jq -r .label <<<"$current")
  say "   $label, last revised $(jq -r .updated <<<"$current"): $(jq -r .rev_note <<<"$current")"
  [[ "$(jq -r .username <<<"$current")" == "$owner" ]] || { say "   belongs to $(jq -r .username <<<"$current"), not $owner; skipped"; failed=1; continue; }
  [[ "$(jq -r .is_public <<<"$current")" == true ]] || { say "   isn't public; skipped"; failed=1; continue; }

  make_script "$how" > "$WORK/$id.new"
  bash -n "$WORK/$id.new" || { say "   the new script has a syntax error; skipped"; failed=1; continue; }
  jq -r .script <<<"$current" > "$WORK/$id.old"
  if same "$WORK/$id.old" "$WORK/$id.new"; then
    say "   already the $VERSION script"; continue
  fi
  changed=1
  before=$(udf_names < "$WORK/$id.old") after=$(udf_names < "$WORK/$id.new")
  say "   $(diff "$WORK/$id.old" "$WORK/$id.new" | grep -c '^[<>]' || true) lines differ"
  [[ "$before" == "$after" ]] || say "   form fields: $before-> $after"
  if (( ! APPLY )); then
    say "   would update it, with the note \"$NOTE\""; continue
  fi
  body=$(jq -n --rawfile script "$WORK/$id.new" --arg note "$NOTE" '{script: $script, rev_note: $note}')
  result=$(api "$token" PUT "/linode/stackscripts/$id" "$body")
  if ! jq -e '.id' >/dev/null 2>&1 <<<"$result"; then
    say "   update failed: $(jq -r '.errors[0].reason // .' <<<"$result" 2>/dev/null)"; failed=1; continue
  fi
  check=$(api "$token" GET "/linode/stackscripts/$id")
  jq -r .script <<<"$check" > "$WORK/$id.check"
  if same "$WORK/$id.check" "$WORK/$id.new"; then
    say "   updated: $(jq -r .updated <<<"$check"), \"$(jq -r .rev_note <<<"$check")\""
  else
    say "   updated, but Linode's copy differs from the new script; check it in Cloud Manager"; failed=1
  fi
done

say ""
if (( failed )); then say "Some StackScripts weren't updated (see above)."; exit 1; fi
if (( ! APPLY && changed )); then say "Run again with --apply to update them."; fi
