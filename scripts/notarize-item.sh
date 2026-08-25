#!/bin/zsh

set -euo pipefail

item="${1:-}"
work_dir="${2:-}"
profile="${INPUTMATE_NOTARY_PROFILE:-retrolife-openemu}"

fail() {
  print -u2 -- "notarize-item.sh: $*"
  exit 1
}

[[ -n "$item" ]] || fail "an app or DMG path is required"
[[ -e "$item" ]] || fail "item not found: $item"
[[ -n "$work_dir" ]] || fail "a notarization work directory is required"

item="${item:A}"
work_dir="${work_dir:A}"
mkdir -p "$work_dir"

submit_and_require_acceptance() {
  local submission="$1"
  local log_path="$2"
  local diagnostic_path="$3"
  local submission_id

  /usr/bin/xcrun notarytool submit "$submission" \
    --keychain-profile "$profile" \
    --wait \
    --output-format json > "$log_path"

  if /usr/bin/grep -Eq \
    '"status"[[:space:]]*:[[:space:]]*"Accepted"' \
    "$log_path"; then
    return 0
  fi

  submission_id="$(
    /usr/bin/plutil -extract id raw -o - "$log_path" 2>/dev/null || true
  )"
  if [[ -n "$submission_id" ]]; then
    /usr/bin/xcrun notarytool log "$submission_id" \
      --keychain-profile "$profile" \
      "$diagnostic_path" >/dev/null 2>&1 || true
  fi

  fail "Apple did not accept notarization for $item; see $log_path and $diagnostic_path"
}

if [[ -d "$item" && "$item" == *.app ]]; then
  submission="$work_dir/$(basename "$item").notarization.zip"
  log_path="$work_dir/$(basename "$item").notarization.json"
  diagnostic_path="$work_dir/$(basename "$item").notarization-log.json"

  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$item" "$submission"
  submit_and_require_acceptance "$submission" "$log_path" "$diagnostic_path"

  /usr/bin/xcrun stapler staple "$item"
  /usr/bin/xcrun stapler validate "$item"
  /usr/sbin/spctl --assess --type execute --verbose=2 "$item"
elif [[ -f "$item" && "$item" == *.dmg ]]; then
  log_path="$work_dir/$(basename "$item").notarization.json"
  diagnostic_path="$work_dir/$(basename "$item").notarization-log.json"

  submit_and_require_acceptance "$item" "$log_path" "$diagnostic_path"

  /usr/bin/xcrun stapler staple "$item"
  /usr/bin/xcrun stapler validate "$item"
  /usr/sbin/spctl --assess \
    --type open \
    --context context:primary-signature \
    --verbose=2 \
    "$item"
else
  fail "item must be an .app bundle or .dmg file"
fi

print -- "notarize-item.sh: notarized, stapled, and assessed $item"
