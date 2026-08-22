#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
package_root="${script_dir:h}"
configuration="${CONFIGURATION:-release}"
app_path="${1:-${package_root}/.build/app/InputMate.app}"
bundle_id="${INPUTMATE_BUNDLE_ID:-com.robot.InputMate}"

# Public builds default to ad-hoc signing so the project can build on any Mac
# without requiring a private certificate. Developers who need a stable macOS
# designated requirement can provide their own signing identity locally:
#
#   CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" zsh scripts/build-app.sh
#
# CODESIGN_REQUIREMENT is optional and is useful when preserving Accessibility
# grants across local rebuilds with a stable team identity.
identity="${CODESIGN_IDENTITY:--}"
requirement="${CODESIGN_REQUIREMENT:-}"

cd "$package_root"
swift build --configuration "$configuration" --product InputMate
binary_dir="$(swift build --configuration "$configuration" --show-bin-path)"

if [[ -e "$app_path" ]]; then
  rm -rf -- "$app_path"
fi

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$package_root/App/Info.plist" "$app_path/Contents/Info.plist"
cp "$binary_dir/InputMate" "$app_path/Contents/MacOS/InputMate"
cp "$package_root/LICENSE" "$app_path/Contents/Resources/LICENSE"

# Keep the bundle identifier overridable without storing machine-specific
# signing configuration in the repository.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" \
  "$app_path/Contents/Info.plist"

codesign_arguments=(--force --options runtime --sign "$identity")
if [[ -n "$requirement" ]]; then
  codesign_arguments+=(--requirements "$requirement")
fi

/usr/bin/codesign "${codesign_arguments[@]}" "$app_path"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"

print -r -- "$app_path"
