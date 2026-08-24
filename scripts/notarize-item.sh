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

if [[ -d "$item" && "$item" == *.app ]]; then
  submission="$work_dir/$(basename "$item").notarization.zip"
  log_path="$work_dir/$(basename "$item").notarization.json"

  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$item" "$submission"
  /usr/bin/xcrun notarytool submit "$submission" \
    --keychain-profile "$profile" \
    --wait \
    --output-format json > "$log_path"
  /usr/bin/grep -Eq '"status"[[:space:]]*:[[:space:]]*"Accepted"' "$log_path" ||
    fail "Apple did not accept notarization for $item; see $log_path"

  /usr/bin/xcrun stapler staple "$item"
  /usr/bin/xcrun stapler validate "$item"
  /usr/sbin/spctl --assess --type execute --verbose=2 "$item"
elif [[ -f "$item" && "$item" == *.dmg ]]; then
  log_path="$work_dir/$(basename "$item").notarization.json"

  /usr/bin/xcrun notarytool submit "$item" \
    --keychain-profile "$profile" \
    --wait \
    --output-format json > "$log_path"
  /usr/bin/grep -Eq '"status"[[:space:]]*:[[:space:]]*"Accepted"' "$log_path" ||
    fail "Apple did not accept notarization for $item; see $log_path"

  /usr/bin/xcrun stapler staple "$item"
  /usr/bin/xcrun stapler validate "$item"
else
  fail "item must be an .app bundle or .dmg file"
fi

print -- "notarize-item.sh: notarized and stapled $item"
