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

Tags matching `v*` trigger the GitHub Actions release workflow. Public release artifacts are ad-hoc signed unless a future release process explicitly adds Developer ID signing and notarization through repository secrets.
