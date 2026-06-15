#!/usr/bin/env bash
# Package a local skill directory (markdown-only, v1) and open/update a PR
# against the team skills repo via the worker.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd jq "Install jq (macOS: brew install jq)"

# --- 1. resolve skill directory --------------------------------------------
SKILL_DIR="${1:-$PWD}"
SKILL_DIR="$(cd "$SKILL_DIR" 2>/dev/null && pwd || true)"
[ -n "$SKILL_DIR" ] && [ -d "$SKILL_DIR" ] || die "Skill directory not found: ${1:-$PWD}"

skill_name="$(basename "$SKILL_DIR")"
[ -n "$skill_name" ] || die "Could not determine skill name from path."

info "Packaging skill '${skill_name}' from: $SKILL_DIR"

# --- 2. collect files; refuse non-markdown ---------------------------------
# Gather all regular files (paths relative to SKILL_DIR).
all_files=()
while IFS= read -r -d '' f; do
  rel="${f#./}"
  all_files+=("$rel")
done < <(cd "$SKILL_DIR" && find . -type f -print0)

[ "${#all_files[@]}" -gt 0 ] || die "No files found in $SKILL_DIR"

md_files=()
for rel in "${all_files[@]}"; do
  case "$rel" in
    *.md) md_files+=("$rel") ;;
    *)
      err "Non-markdown file found: $rel"
      die "v1 of skill-publish only supports markdown (*.md) files. Remove non-.md files and retry."
      ;;
  esac
done

[ "${#md_files[@]}" -gt 0 ] || die "No .md files found in $SKILL_DIR to publish."

info "Found ${#md_files[@]} markdown file(s)."

# --- 3. build JSON payload with jq -----------------------------------------
files_json='[]'
for rel in "${md_files[@]}"; do
  dest="sales-skills/skills/${skill_name}/${rel}"
  content="$(cat "${SKILL_DIR}/${rel}")"
  files_json="$(jq \
    --arg path "$dest" \
    --arg content "$content" \
    '. + [{path: $path, content: $content}]' \
    <<<"$files_json")"
done

message="Publish/update skill: ${skill_name}"
payload="$(jq -n \
  --arg skill_name "$skill_name" \
  --arg message "$message" \
  --argjson files "$files_json" \
  '{skill_name: $skill_name, files: $files, message: $message}')"

# --- 4. POST /publish -------------------------------------------------------
WORKER_URL="$(resolve_worker_url)"

info "Opening pull request via the skills worker..."
response="$(worker_request "$WORKER_URL" POST /publish "$payload")"

pr_url="$(printf '%s' "$response" | jq -r '.pr_url // empty')"
pr_number="$(printf '%s' "$response" | jq -r '.pr_number // empty')"
branch="$(printf '%s' "$response" | jq -r '.branch // empty')"

if [ -z "$pr_url" ]; then
  err "Publish did not return a PR URL. Response was:"
  printf '%s\n' "$response" >&2
  die "Something went wrong. Check the messages above or ping Siim."
fi

# --- 5. report --------------------------------------------------------------
info ""
info "Pull request ready:"
info "  $pr_url"
[ -n "$pr_number" ] && info "  PR #$pr_number"
[ -n "$branch" ]    && info "  branch: $branch"
info ""
info "Re-running /skill-publish on this skill updates the SAME PR (idempotent)."
info "Siim will review and merge — once merged, /skill-sync delivers it to the team."
