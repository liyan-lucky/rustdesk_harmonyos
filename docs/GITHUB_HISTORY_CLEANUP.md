# GitHub History Cleanup

Use `scripts/cleanup_github_history.sh` to clean GitHub Actions workflow run records and Git tags.

## Safety defaults

The script is intentionally conservative:

- It runs in dry-run mode by default.
- It cleans workflow runs and Git tags only when `--yes` is provided.
- It does not delete GitHub Releases or release assets by default.
- Release cleanup requires explicit `--delete-releases`.

## Requirements

Install and authenticate the GitHub CLI:

```bash
gh auth login
```

Install `jq`.

The token/account used by `gh` must have permission to delete workflow runs, tags, and releases in the repository.

## Preview only

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos
```

This prints what would be deleted but does not delete anything.

## Clean workflow runs and tags, keep Releases

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes
```

This deletes workflow run records and Git tags. Published GitHub Release objects and release assets are kept.

## Clean workflow runs only

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-tags
```

## Clean failed workflow runs only

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-tags --failed-only
```

## Clean tags only

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-runs
```

## Keep latest tags

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-runs --keep-latest-tags 5
```

## Keep tags by pattern

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-runs --keep-tag-pattern '^v[0-9]+\.'
```

## Delete Releases too

```bash
scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --delete-releases
```

This is the dangerous mode. It deletes GitHub Release objects and their assets before deleting tags. Use it only after confirming the release artifacts may be removed.

## Notes

- Deleting tags can affect release navigation and version history.
- Deleting releases can remove published HAP files and any attached artifacts.
- Do not use release cleanup as a substitute for license review. If a release contains SDK/toolchain archives that should not be public, remove those assets deliberately and document the action.
- For compliance-sensitive cleanup, record the date, operator, repository, and reason for the cleanup.
