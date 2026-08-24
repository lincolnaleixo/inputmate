# Contributing to InputMate

Thank you for helping improve InputMate. Keep each pull request focused on one user-visible problem or one coherent maintenance change.

## Before making a change

- Search existing issues and pull requests for related work.
- Explain the user problem and the intended behavior.
- Avoid including private shortcuts, local application paths, credentials, signing material, or selected user text.

## Commit messages

Use Conventional Commits because release automation derives the next version and release notes from commits on `main`.

```text
fix(shortcuts): preserve right-side modifier keys
feat(actions): add a menu-item action
docs: explain Accessibility permissions
test(input): cover overlapping shortcut scopes
ci(release): validate published checksums
```

Use `fix` for a user-visible bug and `feat` for backward-compatible functionality. Add `!` and a `BREAKING CHANGE:` footer only when users must take action because compatibility has been broken. Documentation, tests, build work, CI, refactors, and maintenance should use their corresponding non-release types.

The complete version policy is in [`RELEASING.md`](RELEASING.md).

## Verification

Run the repository checks before opening a pull request:

```sh
zsh scripts/mac test
zsh scripts/mac build
git diff --check
```

For input, Accessibility, Automation, update, or UI changes, also test the built app on a Mac with the relevant permissions. Describe what you tested and what you did not test in the pull request.

## Pull requests

A useful pull request includes:

- the problem and expected behavior;
- one focused implementation;
- automated tests where practical;
- commands run and their results;
- screenshots or a short recording for visible UI changes;
- the macOS version and architecture used for manual testing.

Do not edit `CHANGELOG.md`, `version.txt`, or `.release-please-manifest.json` as part of normal feature work. Release Please owns those files through its release pull request.
