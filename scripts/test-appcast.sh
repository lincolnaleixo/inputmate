#!/bin/zsh

set -euo pipefail

root="${0:A:h:h}"
app="$root/.build/app/InputMate.app"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

[[ -d "$app" ]] || {
  print -u2 -- "test-appcast.sh: build InputMate.app first"
  exit 1
}

short_version="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$app/Contents/Info.plist"
)"
build_version="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :CFBundleVersion' \
    "$app/Contents/Info.plist"
)"
[[ "$short_version" != "$build_version" ]] || {
  print -u2 -- "test-appcast.sh: public semver must not be reused as Sparkle build version"
  exit 1
}

key_output="$(
  /usr/bin/swift -e '
    import CryptoKit
    import Foundation

    let key = Curve25519.Signing.PrivateKey()
    print(key.rawRepresentation.base64EncodedString())
    print(key.publicKey.rawRepresentation.base64EncodedString())
  '
)"
private_key="${key_output%%$'\n'*}"
public_key="${key_output##*$'\n'}"
[[ -n "$private_key" && -n "$public_key" ]] || {
  print -u2 -- "test-appcast.sh: could not generate a disposable Ed25519 key"
  exit 1
}

updates="$temporary_directory/updates"
mkdir -p "$updates"
/usr/bin/ditto "$app" "$temporary_directory/InputMate.app"
/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $public_key" \
  "$temporary_directory/InputMate.app/Contents/Info.plist"
/usr/bin/codesign \
  --force \
  --deep \
  --options runtime \
  --entitlements "$root/App/InputMate.debug.entitlements" \
  --sign - \
  "$temporary_directory/InputMate.app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  "$temporary_directory/InputMate.app" \
  "$updates/InputMate.app.zip"

generate_appcast="$(
  find "$root/.build/artifacts" \
    -type f -name generate_appcast -print -quit
)"
[[ -n "$generate_appcast" ]] || {
  print -u2 -- "test-appcast.sh: Sparkle generate_appcast tool was not found"
  exit 1
}
chmod +x "$generate_appcast"

printf '%s' "$private_key" |
  "$generate_appcast" \
    --ed-key-file - \
    --download-url-prefix \
      "https://example.invalid/releases/download/v$short_version/" \
    --maximum-versions 1 \
    --maximum-deltas 0 \
    -o "$temporary_directory/appcast.xml" \
    "$updates"

/usr/bin/grep -Fq 'sparkle:edSignature=' "$temporary_directory/appcast.xml"
/usr/bin/grep -Fq \
  "https://example.invalid/releases/download/v$short_version/InputMate.app.zip" \
  "$temporary_directory/appcast.xml"
/usr/bin/grep -Fq \
  "<sparkle:version>$build_version</sparkle:version>" \
  "$temporary_directory/appcast.xml"
/usr/bin/grep -Fq \
  "<sparkle:shortVersionString>$short_version</sparkle:shortVersionString>" \
  "$temporary_directory/appcast.xml"

print -- "test-appcast.sh: signed appcast generation succeeded for $short_version ($build_version)"
