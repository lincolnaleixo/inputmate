# InputMate

InputMate is a native macOS menu-bar utility for mouse and trackpad input, global keyboard shortcuts, optional AI-backed text transformations, and secure in-app updates.

## Features

- Keep Apple trackpad scrolling natural while reversing mouse-wheel scrolling.
- Record and edit global shortcuts with left and right modifier keys tracked independently.
- Limit shortcuts to selected applications.
- Open applications and URLs, run Apple Shortcuts, send keyboard shortcuts, press menu items, type text, and trigger macOS actions.
- Transform selected text with Cerebras while storing the API key in macOS Keychain.
- Check for, download, and install signed updates with Sparkle.
- Launch automatically at login.

## Requirements

- macOS 13 or later
- Accessibility access for input handling and menu-item actions
- Automation access for the macOS actions that require System Events
- A Cerebras API key only if you want to use AI text transformations

## Install

### Homebrew

The InputMate repository also acts as its upstream Homebrew tap:

```sh
brew tap matrix-hq/inputmate https://github.com/matrix-hq/inputmate
brew install --cask matrix-hq/inputmate/inputmate
```

The fully qualified cask name lets Homebrew trust only InputMate instead of the entire third-party tap. The explicit repository URL is required because this application repository does not use a separate `homebrew-` repository.

To update or uninstall through Homebrew:

```sh
brew update
brew upgrade --cask matrix-hq/inputmate/inputmate
brew uninstall --cask matrix-hq/inputmate/inputmate
```

InputMate is currently distributed through this upstream tap rather than the official `homebrew/cask` catalog. Official release artifacts are signed with the InputMate Developer ID identity and notarized by Apple before publication.

### Manual installation

Download the latest `InputMate.dmg` from GitHub Releases, open it, and drag `InputMate.app` onto the included **Applications** shortcut.

The release also contains `InputMate.app.zip`, which is the compact payload used by Sparkle for in-app updates. The DMG is the primary installer for people downloading InputMate manually.

Official release builds are signed with Developer ID, hardened, notarized, and stapled. CI and local builds remain ad-hoc by default, so artifacts produced outside the official release workflow may still require explicit approval in **System Settings > Privacy & Security**.

After launching InputMate, grant Accessibility access when prompted if you enable mouse reversal or keyboard shortcuts.

## Automatic updates

InputMate uses Sparkle 2. The menu includes **Check for Updates…** for a user-initiated check. On the second launch, Sparkle asks whether it may check automatically in the background. Automatic download and installation is selected by default in that consent prompt, and the user remains in control of the preference.

The app reads its signed appcast from the latest GitHub Release. Every update archive and the appcast itself are signed with a dedicated Ed25519 key, and InputMate verifies the update before extraction.

## AI text transformations

InputMate includes factory shortcuts for translating selected text to Spanish or English and improving writing. The API key is stored in macOS Keychain and is never written to application preferences or source files.

The transformation request sends the selected text to the configured Cerebras API endpoint. If you do not want selected text sent to an external service, leave the API key unset and do not use transformation actions.

## Shortcut manager

Choose **Manage Shortcuts…** from the menu bar to add or edit shortcuts. A shortcut can:

- Open an application or URL
- Run an Apple Shortcut
- Send another keyboard shortcut
- Transform selected text
- Press a menu-bar item in the frontmost application
- Type custom text
- Hide other applications
- Open or dismiss Notification Center
- Put the Mac to sleep

Shortcuts can be global or limited to one or more application bundle identifiers. InputMate detects conflicts between enabled shortcuts whose scopes overlap.

## Build from source

```sh
zsh scripts/mac doctor
zsh scripts/mac test
zsh scripts/mac build
open .build/app/InputMate.app
```

The build script uses ad-hoc signing by default so it works without private Apple signing material. It embeds Sparkle, the GPL license, and the version recorded in `version.txt`.

To create the same drag-to-Applications installer used by GitHub Releases:

```sh
zsh scripts/create-dmg.sh .build/app/InputMate.app dist/InputMate.dmg
```

To use your own stable Apple signing identity:

```sh
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" zsh scripts/build-app.sh
```

You can also provide `CODESIGN_REQUIREMENT` if you need to preserve a specific designated requirement across local rebuilds. Official releases use the fixed InputMate bundle requirement for Team ID `4F3CBH5L9D`.

## Releases

Release Please watches conventional commits on `main` and maintains a release pull request with the next semantic version and changelog. Merging that release pull request invokes the macOS release workflow.

The release workflow:

- runs the policy tests;
- builds and validates `InputMate.app` on the trusted Apple Silicon `runner-macos-01` self-hosted runner;
- signs the app and embedded Sparkle helpers with `Developer ID Application: BUYFROMUS LLC (4F3CBH5L9D)`;
- notarizes and staples both the app and the DMG before creating final release archives;
- creates `InputMate.dmg` with an Applications shortcut for manual installation;
- creates `InputMate.app.zip` as the Sparkle update payload;
- creates SHA-256 checksums for both packages;
- requires the Sparkle private seed matching `SUPublicEDKey` and generates a signed `appcast.xml`;
- uploads the installer, updater payload, checksums, and appcast to GitHub Releases;
- reads the published files back and verifies their checksums and stapled signatures;
- refreshes `Casks/inputmate.rb` and the signed `release/appcast.xml` snapshot.

When Release Please creates the stable tag and GitHub Release, it invokes the same release workflow directly so the signed assets are attached exactly once.

`workflow_dispatch` supports a verify-only run that performs the build and Apple notarization but does not publish a GitHub Release. Official releases fail closed when the matching Sparkle seed is unavailable instead of preserving an appcast for a different version.

## Security

- API credentials belong in macOS Keychain.
- The Sparkle private update key must remain outside the public repository and public workflow logs.
- Signing identities and certificates are local configuration and must not be committed.
- The release workflow reads `MAC_BUILD_KEYCHAIN_PASSWORD` and `SPARKLE_PRIVATE_KEY` only from GitHub Actions secrets. Their canonical broker references are `robots_mac_server.default.default.build_keychain_password` and `inputmate.default.default.sparkle_private_key`.
- Environment files, private keys, certificates, provisioning profiles, and common local secret files are ignored by Git.
- Selected text is not written to application logs.

If you discover a security issue, avoid including secrets or private user data in a public issue.

## License

InputMate is licensed under the GNU General Public License version 3 only (`GPL-3.0-only`). See [`LICENSE`](LICENSE) for the complete terms.
