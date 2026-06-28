#!/usr/bin/env bash
set -euo pipefail

# Clean GitHub Actions workflow runs and Git tags for this repository.
# Default mode is dry-run. Nothing is deleted unless --yes is passed.
# Release objects/assets are NOT deleted by default. Use --delete-releases to remove releases too.

REPO="${GITHUB_REPOSITORY:-}"
DRY_RUN=1
DELETE_WORKFLOW_RUNS=1
DELETE_TAGS=1
DELETE_RELEASES=0
KEEP_LATEST_TAGS=0
KEEP_TAG_PATTERN=""
DELETE_FAILED_ONLY=0
MAX_RUNS=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/cleanup_github_history.sh --repo OWNER/REPO [options]

Default behavior:
  - Dry-run only.
  - Shows GitHub Actions workflow runs that would be deleted.
  - Shows Git tags that would be deleted.
  - Does NOT delete GitHub Releases or release assets.

Required when GITHUB_REPOSITORY is not set:
  --repo OWNER/REPO

Execution switch:
  --yes                    Actually delete selected items. Without this, the script only prints actions.

Scope switches:
  --runs                   Clean workflow runs. Enabled by default.
  --tags                   Clean Git tags. Enabled by default.
  --no-runs                Do not clean workflow runs.
  --no-tags                Do not clean Git tags.
  --delete-releases        Also delete GitHub Releases and their assets. Off by default.
                           Use this only after confirming published artifacts may be removed.

Safety filters:
  --failed-only            Delete only failed/cancelled/timed_out workflow runs.
  --max-runs N             Delete at most N workflow runs.
  --keep-latest-tags N     Keep the newest N tags by tagger/commit date when deleting tags.
  --keep-tag-pattern REGEX Keep tags matching REGEX, for example '^v[0-9]+\.'

Examples:
  # Preview cleanup for this repository
  scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos

  # Actually delete all workflow runs and all tags, but keep releases/assets
  scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes

  # Delete workflow runs only, keep tags and releases
  scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-tags

  # Delete failed/cancelled workflow runs only
  scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-tags --failed-only

  # Delete all tags except latest 5, keep releases/assets
  scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --no-runs --keep-latest-tags 5

  # Dangerous: delete releases/assets too, then delete tags
  scripts/cleanup_github_history.sh --repo liyan-lucky/rustdesk_harmonyos --yes --delete-releases
USAGE
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_tools() {
  command -v gh >/dev/null 2>&1 || fail "GitHub CLI 'gh' is required. Install it and run 'gh auth login'."
  command -v jq >/dev/null 2>&1 || fail "jq is required."
  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated. Run 'gh auth login' first."
}

run_or_print() {
  local label="$1"
  shift
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: $label"
  else
    log "RUN: $label"
    "$@"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo)
        [ "$#" -ge 2 ] || fail "--repo requires OWNER/REPO"
        REPO="$2"
        shift 2
        ;;
      --yes)
        DRY_RUN=0
        shift
        ;;
      --runs)
        DELETE_WORKFLOW_RUNS=1
        shift
        ;;
      --tags)
        DELETE_TAGS=1
        shift
        ;;
      --no-runs)
        DELETE_WORKFLOW_RUNS=0
        shift
        ;;
      --no-tags)
        DELETE_TAGS=0
        shift
        ;;
      --delete-releases)
        DELETE_RELEASES=1
        shift
        ;;
      --failed-only)
        DELETE_FAILED_ONLY=1
        shift
        ;;
      --max-runs)
        [ "$#" -ge 2 ] || fail "--max-runs requires a number"
        MAX_RUNS="$2"
        shift 2
        ;;
      --keep-latest-tags)
        [ "$#" -ge 2 ] || fail "--keep-latest-tags requires a number"
        KEEP_LATEST_TAGS="$2"
        shift 2
        ;;
      --keep-tag-pattern)
        [ "$#" -ge 2 ] || fail "--keep-tag-pattern requires a regex"
        KEEP_TAG_PATTERN="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done

  [ -n "$REPO" ] || fail "Repository is required. Pass --repo OWNER/REPO or set GITHUB_REPOSITORY."
  [[ "$REPO" == */* ]] || fail "Repository must be in OWNER/REPO form: $REPO"

  if ! [[ "$KEEP_LATEST_TAGS" =~ ^[0-9]+$ ]]; then
    fail "--keep-latest-tags must be a non-negative integer"
  fi
  if [ -n "$MAX_RUNS" ] && ! [[ "$MAX_RUNS" =~ ^[0-9]+$ ]]; then
    fail "--max-runs must be a non-negative integer"
  fi
}

cleanup_releases() {
  if [ "$DELETE_RELEASES" -ne 1 ]; then
    log "Release cleanup: disabled. Published release contents/assets will be kept."
    return 0
  fi

  warn "Release cleanup is enabled. This deletes GitHub Release objects and their assets."
  gh api --paginate "/repos/$REPO/releases?per_page=100" |
    jq -r '.[] | [.id, .tag_name, .name] | @tsv' |
    while IFS=$'\t' read -r release_id tag_name release_name; do
      [ -n "$release_id" ] || continue
      run_or_print "delete release id=$release_id tag=$tag_name name=$release_name" \
        gh api -X DELETE "/repos/$REPO/releases/$release_id"
    done
}

cleanup_workflow_runs() {
  [ "$DELETE_WORKFLOW_RUNS" -eq 1 ] || { log "Workflow run cleanup: disabled."; return 0; }

  local count=0
  gh api --paginate "/repos/$REPO/actions/runs?per_page=100" |
    jq -r '.workflow_runs[] | [.id, .name, .status, .conclusion, .created_at] | @tsv' |
    while IFS=$'\t' read -r run_id name status conclusion created_at; do
      [ -n "$run_id" ] || continue

      if [ "$DELETE_FAILED_ONLY" -eq 1 ]; then
        case "$conclusion" in
          failure|cancelled|timed_out|action_required|startup_failure) ;;
          *) continue ;;
        esac
      fi

      count=$((count + 1))
      if [ -n "$MAX_RUNS" ] && [ "$count" -gt "$MAX_RUNS" ]; then
        continue
      fi

      run_or_print "delete workflow run id=$run_id name=$name status=$status conclusion=$conclusion created=$created_at" \
        gh api -X DELETE "/repos/$REPO/actions/runs/$run_id"
    done
}

cleanup_tags() {
  [ "$DELETE_TAGS" -eq 1 ] || { log "Tag cleanup: disabled."; return 0; }

  local tags_json
  tags_json="$(gh api --paginate "/repos/$REPO/tags?per_page=100" | jq -s 'add')"

  local total
  total="$(jq 'length' <<<"$tags_json")"
  if [ "$total" -eq 0 ]; then
    log "No tags found."
    return 0
  fi

  jq -r '.[].name' <<<"$tags_json" | nl -v 1 -w 1 -s $'\t' |
    while IFS=$'\t' read -r index tag_name; do
      [ -n "$tag_name" ] || continue

      if [ "$KEEP_LATEST_TAGS" -gt 0 ] && [ "$index" -le "$KEEP_LATEST_TAGS" ]; then
        log "KEEP: tag=$tag_name reason=latest-$KEEP_LATEST_TAGS"
        continue
      fi

      if [ -n "$KEEP_TAG_PATTERN" ] && [[ "$tag_name" =~ $KEEP_TAG_PATTERN ]]; then
        log "KEEP: tag=$tag_name reason=pattern"
        continue
      fi

      run_or_print "delete tag ref=refs/tags/$tag_name" \
        gh api -X DELETE "/repos/$REPO/git/refs/tags/$tag_name"
    done
}

main() {
  parse_args "$@"
  require_tools

  log "Repository: $REPO"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "Dry-run mode. No remote data will be deleted. Add --yes to execute."
  else
    warn "Execution mode. Selected remote data will be deleted."
  fi

  # Delete releases first when explicitly enabled, because releases are associated with tags.
  cleanup_releases
  cleanup_workflow_runs
  cleanup_tags

  log "Done."
}

main "$@"
