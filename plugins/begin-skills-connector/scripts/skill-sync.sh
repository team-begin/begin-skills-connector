#!/usr/bin/env bash
# Install/update Begin's reviewed team skills.
# Fetches a short-lived GitHub read token from the worker, then uses the
# `claude` CLI to add/update the private marketplace and install the skills.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd jq "Install jq (macOS: brew install jq)"
require_cmd claude "Install the Claude Code CLI: https://docs.anthropic.com/claude-code"

WORKER_URL="$(resolve_worker_url)"

info "Requesting access token from the skills worker..."
response="$(worker_request "$WORKER_URL" GET /token)"

token="$(printf '%s' "$response" | jq -r '.token // empty')"
repo="$(printf '%s' "$response" | jq -r '.repo // "team-begin/claude-plugins"')"

if [ -z "$token" ]; then
  err "Did not receive a token from the worker. Response was:"
  printf '%s\n' "$response" >&2
  die "Authentication likely failed. Run: cloudflared access login --app=\"$WORKER_URL\""
fi

info "Got token. Syncing marketplace '${repo}'..."

# Add the marketplace (ignore error if already added), then update it.
GITHUB_TOKEN="$token" claude plugin marketplace add "$repo" 2>/dev/null || true
GITHUB_TOKEN="$token" claude plugin marketplace update begin-claude-plugins

# Install (or no-op if already installed).
claude plugin install sales-skills@begin-claude-plugins 2>/dev/null || true

info ""
info "Done. Team skills installed/updated from the reviewed 'main' branch."
info "These are the vetted versions — your local edits are never overwritten by sync."
