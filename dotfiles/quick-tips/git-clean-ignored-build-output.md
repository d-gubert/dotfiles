# Remove ignored build output

```sh
git clean -fdX packages ee/packages
```

**What:** deletes the git-ignored files and directories under the given paths (`dist/`, `.turbo/`, …). Tracked and untracked-but-not-ignored files stay.

- `-f` force, `-d` recurse into directories, `-X` only ignored files.
- Preview first with `-n`: `git clean -ndX packages ee/packages`.

**When:** the build passes locally but fails in CI. Stale output from an old build can hide a missing file. Clean, then run the full build to reproduce the CI state.
