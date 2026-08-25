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

- Apple silicon Mac (`arm64`)
- macOS 13 or later
- Accessibility access for input handling and menu-item actions
- Automation access for the macOS actions that require System Events
- A Cerebras API key only if you want to use AI text transformations

## Install

### Homebrew

The InputMate repository also acts as its upstream Homebrew tap:

```sh
brew tap lincolnaleixo/inputmate https://github.com/lincolnaleixo/inputmate
brew install --cask lincolnaleixo/inputmate/inputmate
```

The fully qualified cask name lets Homebrew trust only InputMate instead of the entire third-party tap. The explicit repository URL is required because this application repository does not use a separate `homebrew-` repository.

To update or uninstall through Homebrew:

```sh
brew update
brew upgrade --cask lincolnaleixo/inputmate/inputmate
brew uninstall --cask lincolnaleixo/inputmate/inputmate
```

InputMate is currently distributed through this upstream tap rather than the official `homebrew/cask` catalog. Official release artifacts are signed with Developer ID and notarized by Apple before publication.

### Manual installation

Download the latest `InputMate.dmg` from GitHub Releases, open it, and drag `InputMate.app` onto the included **Applications** shortcut.

The release also contains `InputMate.app.zip`, which is the compact payload used by Sparkle for in-app updates. The DMG is the primary installer for people downloading InputMate manually.

Official release builds are signed with Developer ID, hardened, notarized, stapled, and assessed by Gatekeeper. CI and local builds remain ad-hoc by default, so artifacts produced outside the official release workflow may still require explicit approval in **System Settings > Privacy & Security**.

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

You can also provide `CODESIGN_REQUIREMENT` if you need to preserve a specific designated requirement across local rebuilds. Official releases use a stable Developer ID identity and designated requirement.

## Releases

InputMate follows Semantic Versioning and uses conventional commits. Release Please watches `main` and maintains a release pull request containing the next version and changelog. Merging that release pull request is the only action that publishes a new version.

See [`RELEASING.md`](RELEASING.md) for the version rules, commit examples, release checklist, and recovery procedure. Contributors should also read [`CONTRIBUTING.md`](CONTRIBUTING.md).

The release workflow:

- runs the policy tests;
- builds and validates `InputMate.app` on a dedicated trusted Apple silicon runner;
- signs the app and embedded Sparkle helpers with Developer ID and a secure timestamp;
- uses release entitlements that keep Library Validation enabled;
- notarizes, staples, and Gatekeeper-assesses both the app and the DMG;
- creates `InputMate.dmg` with an Applications shortcut for manual installation;
- creates `InputMate.app.zip` as the Sparkle update payload;
- creates SHA-256 checksums for both packages after stapling;
- requires the Sparkle private seed matching `SUPublicEDKey` and generates a signed `appcast.xml`;
- uploads the installer, updater payload, checksums, and appcast to GitHub Releases;
- downloads the published files again and verifies checksums, signatures, notarization tickets, and Gatekeeper acceptance;
- refreshes `Casks/inputmate.rb` and the signed `release/appcast.xml` snapshot.

When Release Please creates the stable tag and GitHub Release, it invokes the same release workflow directly so the signed assets are attached exactly once.

Manual `workflow_dispatch` runs are always verify-only. They perform the complete build and Apple notarization but cannot publish or modify a GitHub Release. Official releases fail closed when signing, notarization, Gatekeeper, checksum, or Sparkle validation is unavailable.

## Security

- API credentials belong in macOS Keychain.
- The Sparkle private update key must remain outside the public repository and public workflow logs.
- Signing identities and certificates are private release infrastructure and must not be committed.
- The release workflow reads its keychain password and Sparkle signing key only from GitHub Actions secrets.
- Environment files, private keys, certificates, provisioning profiles, and common local secret files are ignored by Git.
- Selected text is not written to application logs.

If you discover a security issue, avoid including secrets or private user data in a public issue.

## License

InputMate is licensed under the GNU General Public License version 3 only (`GPL-3.0-only`). See [`LICENSE`](LICENSE) for the complete terms.
