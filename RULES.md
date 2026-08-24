# InputMate Repository

InputMate is a native macOS menu-bar utility for mouse and trackpad input, global keyboard shortcuts, and optional AI-backed text transformations.

## Architecture

- Swift Package Manager project targeting macOS 13 or later.
- `App/` contains bundle resources such as `Info.plist`.
- `Sources/InputMate/` contains the macOS application.
- `Sources/InputMateCore/` contains policies that can be tested without AppKit.
- `Tests/InputMatePolicyTests/` contains the executable policy test suite.
- `scripts/build-app.sh` creates the application bundle.

## Security and privacy

- Never commit API keys, passwords, signing certificates, provisioning profiles, private hostnames, or machine-specific credentials.
- Store the Cerebras API key only in macOS Keychain.
- Keep personal shortcuts, application paths, and local deployment configuration in user preferences rather than factory defaults.
- Do not log selected user text or API credentials.

## Development

- Use Swift Package Manager and preserve the native macOS architecture.
- Preserve left- and right-side modifier distinctions in shortcut handling.
- Accessibility and Automation permissions are user-granted macOS boundaries. Tests must not assume those permissions are available.
- Keep the app bundle signed. Public builds may use ad-hoc signing; local developers can provide `CODESIGN_IDENTITY` when they need a stable designated requirement.

## Verification

Before opening a pull request:

```sh
zsh scripts/mac test
zsh scripts/mac build
git diff --check
```

For input, Accessibility, or UI behavior changes, also exercise the built app on a Mac with the relevant permissions granted.

## Releases

Release Please invokes the GitHub Actions release workflow after it creates the stable tag and GitHub Release. Pull request CI remains ad-hoc on a GitHub-hosted runner, while official releases run on the repository-level `runner-inputmate-macos-01` runner and use the existing Developer ID certificate, trusted keychain, and notarization profile on `robots-mac-server`.

Merging the Release Please pull request is the only publication gate. A manual release workflow run is always verify-only and must never create, replace, or modify a GitHub Release. Follow `RELEASING.md`; do not manually edit generated version or changelog files during normal development.

Official releases must use the fixed bundle requirement for `com.robot.InputMate` and Team ID `4F3CBH5L9D`, notarize and staple the app and DMG, regenerate checksums after stapling, and generate a signed Sparkle appcast from the final ZIP. The Sparkle private seed and keychain password are secrets and must never enter this repository.

The canonical broker references are `inputmate.default.default.sparkle_private_key` for Sparkle and `robots_mac_server.default.default.build_keychain_password` for the build keychain. GitHub repository secrets are copies and must be refreshed after either canonical value rotates.
