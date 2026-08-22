# InputMate

InputMate is a native macOS menu-bar utility for mouse and trackpad input, global keyboard shortcuts, and optional AI-backed text transformations.

## Features

- Keep Apple trackpad scrolling natural while reversing mouse-wheel scrolling.
- Record and edit global shortcuts with left and right modifier keys tracked independently.
- Limit shortcuts to selected applications.
- Open applications and URLs, run Apple Shortcuts, send keyboard shortcuts, press menu items, type text, and trigger macOS actions.
- Transform selected text with Cerebras while storing the API key in macOS Keychain.
- Launch automatically at login.

## Requirements

- macOS 13 or later
- Accessibility access for input handling and menu-item actions
- Automation access for the macOS actions that require System Events
- A Cerebras API key only if you want to use AI text transformations

## Install

Download the latest `InputMate.app.zip` from GitHub Releases, unzip it, and move `InputMate.app` to `/Applications`.

Public release builds are ad-hoc signed. macOS may require you to explicitly approve the first launch in **System Settings > Privacy & Security**. A future release process can add Developer ID signing and notarization without changing the source build.

After launching InputMate, grant Accessibility access when prompted if you enable mouse reversal or keyboard shortcuts.

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

The build script uses ad-hoc signing by default so it works without private signing material. To use your own stable Apple signing identity:

```sh
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" zsh scripts/build-app.sh
```

You can also provide `CODESIGN_REQUIREMENT` if you need to preserve a specific designated requirement across local rebuilds.

## Releases

Pushing a tag such as `v0.1.0` triggers the release workflow. The workflow runs the test suite on a GitHub-hosted macOS runner, builds an ad-hoc signed app, packages `InputMate.app.zip`, creates a SHA-256 checksum, and publishes both files to GitHub Releases.

## Security

- API credentials belong in macOS Keychain.
- Signing identities and certificates are local configuration and must not be committed.
- Environment files, private keys, certificates, provisioning profiles, and common local secret files are ignored by Git.
- Selected text is not written to application logs.

If you discover a security issue, avoid including secrets or private user data in a public issue.

## License

InputMate is licensed under the GNU General Public License version 3 only (`GPL-3.0-only`). See [`LICENSE`](LICENSE) for the complete terms.
