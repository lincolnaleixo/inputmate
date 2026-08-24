# Pull request

## Summary

Describe the user problem and the focused change that solves it.

## Related issue

Link the issue or discussion when one exists.

## Verification

List the commands run, manual steps performed, macOS version, and architecture. Include screenshots or a short recording for visible UI changes.

## Checklist

- [ ] The pull request contains one coherent change.
- [ ] The commit or squash title follows Conventional Commits.
- [ ] `zsh scripts/mac test` passes.
- [ ] `zsh scripts/mac build` passes.
- [ ] `git diff --check` passes.
- [ ] User-visible behavior and documentation are consistent.
- [ ] No credentials, signing material, private paths, or selected user text are included.
