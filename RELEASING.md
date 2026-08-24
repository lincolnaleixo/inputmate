# Releasing InputMate

InputMate uses [Semantic Versioning](https://semver.org/) and [Release Please](https://github.com/googleapis/release-please). Normal development lands on `main`; a release is published only when a maintainer merges the automated release pull request.

## Version policy

The release version has the form `MAJOR.MINOR.PATCH`:

| Change | Commit example | Version result from 0.2.0 |
| --- | --- | --- |
| Backward-compatible bug fix | `fix(input): correct mouse-wheel direction` | `0.2.1` |
| Backward-compatible feature | `feat(shortcuts): add application groups` | `0.3.0` |
| Incompatible change | `feat!: replace the shortcut storage format` | `1.0.0` |

InputMate uses strict SemVer even while the major version is zero. A breaking commit therefore proposes `1.0.0`, not another `0.x` release. Use a breaking change only when existing users, preferences, integrations, or update behavior require migration.

The following commit types do not create a release by themselves and are hidden from user-facing release notes: `docs`, `refactor`, `test`, `build`, `ci`, and `chore`. Use `ci(release): ...` or `build(release): ...` for release-pipeline maintenance. Reserve `fix:` for behavior that changes for users.

If a specific next version is genuinely required, put this trailer in the body of an appropriate commit:

```text
Release-As: 0.3.0
```

Do not use `Release-As` to reuse or replace an existing version.

## Normal release flow

1. Merge tested conventional commits into `main`.
2. Release Please opens or updates `chore(main): release X.Y.Z`.
3. Review that pull request. Confirm the proposed version, `CHANGELOG.md`, `version.txt`, and `.release-please-manifest.json`.
4. Leave the pull request open while more changes should be included. Release Please keeps it updated.
5. Merge the release pull request only when that exact version is ready for users.
6. Release Please creates tag `vX.Y.Z` and the GitHub Release. It then calls the trusted macOS release workflow.
7. The release workflow signs, notarizes, staples, packages, signs the Sparkle update, publishes the assets, downloads them again, and verifies them independently.

There is no release calendar enforced by automation. Merge the release pull request when the accumulated changes are worth shipping and the checks are green. The merge is the publication approval, so do not merge it as routine repository housekeeping.

## Verify without publishing

Run the `Release` workflow manually from GitHub Actions, or use:

```sh
gh workflow run release.yml --ref main
```

You may provide an existing semantic tag to verify that exact source:

```sh
gh workflow run release.yml --ref main -f tag=v0.2.0
```

A manual run is always verify-only. It still uses the Developer ID certificate and submits the build to Apple, but it cannot create or modify a GitHub Release. Its signed artifacts are retained as workflow artifacts for inspection.

## Publication gates

An official release is accepted only after all of these checks pass:

- Swift policy tests;
- Developer ID identity, Team ID, hardened runtime, timestamp, entitlements, and designated requirement;
- Apple notarization and stapling for the app and DMG;
- Gatekeeper assessment with `spctl`;
- Sparkle public/private key match and EdDSA signature verification;
- checksums generated from the final stapled packages;
- published asset download and checksum verification;
- Homebrew cask installation into an isolated application directory.

The workflow publishes these assets:

- `InputMate.dmg` and its SHA-256 checksum for manual installation;
- `InputMate.app.zip` and its SHA-256 checksum for Sparkle;
- `appcast.xml` for automatic updates.

After verification, automation refreshes `Casks/inputmate.rb` and the repository snapshot at `release/appcast.xml`.

## Generated files and secrets

Release Please owns `CHANGELOG.md`, `version.txt`, and `.release-please-manifest.json`. Do not change them during ordinary development.

The release runner reads GitHub repository copies of these canonical broker values:

| GitHub secret | Canonical broker reference |
| --- | --- |
| `MAC_BUILD_KEYCHAIN_PASSWORD` | `robots_mac_server.default.default.build_keychain_password` |
| `SPARKLE_PRIVATE_KEY` | `inputmate.default.default.sparkle_private_key` |

Refresh the GitHub copy after rotating either broker value. Never put a secret value in the repository, workflow arguments, documentation, or logs.

## Failed releases

If the release workflow fails, fix the cause and rerun the failed workflow. Do not move the tag, replace released files manually, or reuse the version for different source code. SemVer requires released contents to remain immutable.

If a code change is needed after a version has been published, merge a conventional fix and let Release Please propose the next patch version.
