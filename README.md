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

Download the latest `InputMate.dmg` from GitHub Releases, open it, and drag `InputMate.app` onto the included **Applications** shortcut.

The release also contains `InputMate.app.zip`, which is the compact payload used by Sparkle for in-app updates. The DMG is the primary installer for people downloading InputMate manually.

Public release builds are ad-hoc signed. macOS may require you to explicitly approve the first launch in **System Settings > Privacy & Security**. A future release process can add Developer ID signing and notarization without changing the source build.

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

You can also provide `CODESIGN_REQUIREMENT` if you need to preserve a specific designated requirement across local rebuilds.

## Releases

Release Please watches conventional commits on `main` and maintains a release pull request with the next semantic version and changelog. Merging that release pull request invokes the macOS release workflow.

The release workflow:

- runs the policy tests;
- builds and validates `InputMate.app` on a GitHub-hosted macOS runner;
- creates `InputMate.dmg` with an Applications shortcut for manual installation;
- creates `InputMate.app.zip` as the Sparkle update payload;
- creates SHA-256 checksums for both packages;
- generates and signs `appcast.xml` when the matching Sparkle private key is available;
- uploads the installer, updater payload, checksums, and appcast to GitHub Releases.

A manually pushed stable tag such as `v0.1.0` also invokes the same release workflow.

DMG and ZIP packaging does not require private signing material. Publishing a new version through Sparkle requires the private Ed25519 seed that matches the `SUPublicEDKey` embedded in `App/Info.plist`. When that key is not available to the runner, the workflow preserves the last valid signed appcast rather than replacing it with an unsigned feed.

## Security

- API credentials belong in macOS Keychain.
- The Sparkle private update key must remain outside the public repository and public workflow logs.
- Signing identities and certificates are local configuration and must not be committed.
- Environment files, private keys, certificates, provisioning profiles, and common local secret files are ignored by Git.
- Selected text is not written to application logs.

If you discover a security issue, avoid including secrets or private user data in a public issue.

## License

InputMate is licensed under the GNU General Public License version 3 only (`GPL-3.0-only`). See [`LICENSE`](LICENSE) for the complete terms.
