# InputMate Repository

InputMate is a native macOS menu-bar utility for mouse and trackpad input, global keyboard shortcuts, and optional AI-backed text transformations.

## Architecture

- Swift Package Manager project targeting Apple silicon and macOS 13 or later.
- `App/` contains bundle resources such as `Info.plist` and signing entitlements.
- `Sources/InputMate/` contains the macOS application.
- `Sources/InputMateCore/` contains policies that can be tested without AppKit.
- `Tests/InputMatePolicyTests/` contains the executable policy test suite.
- `scripts/build-app.sh` creates the application bundle.

## Security and privacy

- Never commit API keys, passwords, signing certificates, provisioning profiles, private hostnames, machine-specific credentials, or release-runner details.
- Store the Cerebras API key only in macOS Keychain.
- Keep personal shortcuts, application paths, and local deployment configuration in user preferences rather than factory defaults.
- Do not log selected user text or API credentials.
- Keep debug-only entitlements separate from release entitlements. Official releases must keep Library Validation enabled.

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

Release Please invokes the GitHub Actions release workflow after it creates the stable tag and GitHub Release. Pull request CI remains ad-hoc on a GitHub-hosted runner, while official releases run on a dedicated trusted macOS runner with access to the Developer ID identity and Apple notarization credentials.

Merging the Release Please pull request is the only publication gate. A manual release workflow run is always verify-only and must never create, replace, or modify a GitHub Release. Follow `RELEASING.md`; do not manually edit generated version or changelog files during normal development.

Official releases must use the fixed InputMate bundle identifier and stable designated requirement, keep Library Validation enabled, notarize and staple the app and DMG, assess both with Gatekeeper, regenerate checksums after stapling, and generate a signed Sparkle appcast from the final ZIP. The Sparkle private seed, signing keychain password, certificate, and notarization credentials are secrets and must never enter this repository.
