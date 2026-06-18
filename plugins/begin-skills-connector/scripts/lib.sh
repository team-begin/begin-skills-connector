#!/usr/bin/env bash
# Shared helpers for the Begin skills connector.
# Sourced by skill-sync.sh and skill-publish.sh.
set -euo pipefail

# Default worker URL (the deployed Begin skills worker, behind Cloudflare Access).
# Override via env BEGIN_SKILLS_WORKER_URL or ~/.config/begin-skills/config.
DEFAULT_WORKER_URL="https://skills.begin.eu"
CONFIG_FILE="${HOME}/.config/begin-skills/config"

# --- output helpers ---------------------------------------------------------
err()  { printf 'ERROR: %s\n' "$*" >&2; }
info() { printf '%s\n' "$*"; }

die() {
  err "$*"
  exit 1
}

# --- dependency checks ------------------------------------------------------
require_cmd() {
  local cmd="$1" hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Required command not found: $cmd"
    [ -n "$hint" ] && err "  $hint"
    exit 1
  fi
}

# --- worker URL resolution --------------------------------------------------
# Order: env BEGIN_SKILLS_WORKER_URL > config file > placeholder default.
resolve_worker_url() {
  local url=""
  if [ -n "${BEGIN_SKILLS_WORKER_URL:-}" ]; then
    url="${BEGIN_SKILLS_WORKER_URL}"
  elif [ -f "$CONFIG_FILE" ]; then
    url="$(tr -d '[:space:]' < "$CONFIG_FILE")"
  else
    url="$DEFAULT_WORKER_URL"
  fi

  if [ -z "$url" ]; then
    die "Could not resolve worker URL. Set BEGIN_SKILLS_WORKER_URL or write it to $CONFIG_FILE"
  fi

  # strip any trailing slash
  printf '%s' "${url%/}"
}

# --- authenticated request helper -------------------------------------------
# Usage: worker_request <worker_url> <method> <path> [body_json]
# Prints the raw HTTP response body to stdout. On HTTP error, prints guidance
# to stderr and exits non-zero.
# Uses `cloudflared access curl` when available (attaches Google identity),
# otherwise falls back to plain curl (browser cookie / unauthenticated).
worker_request() {
  local worker_url="$1" method="$2" path="$3" body="${4:-}"
  local full_url="${worker_url}${path}"
  local tmp_body http_code
  tmp_body="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_body'" RETURN

  require_cmd curl

  # Authenticate to Cloudflare Access: fetch a short-lived token via cloudflared
  # and attach it as the cf-access-token header. This is robust across cloudflared
  # versions (the `cloudflared access curl --app=...` form changed and breaks on
  # newer releases).
  local access_token=""
  if command -v cloudflared >/dev/null 2>&1; then
    access_token="$(cloudflared access token --app="$worker_url" 2>/dev/null || true)"
    if [ -z "$access_token" ]; then
      err "Could not get a Cloudflare Access token."
      err "Log in once with:  cloudflared access login --app=\"$worker_url\""
    fi
  else
    err "cloudflared not found — install it and log in:"
    err "  brew install cloudflared && cloudflared access login --app=\"$worker_url\""
  fi

  local -a curl_args=(
    -sS
    -X "$method"
    -o "$tmp_body"
    -w '%{http_code}'
    -H 'Content-Type: application/json'
  )
  [ -n "$access_token" ] && curl_args+=(-H "cf-access-token: $access_token")
  if [ -n "$body" ]; then
    curl_args+=(--data-binary "$body")
  fi

  http_code="$(curl "${curl_args[@]}" "$full_url" || true)"

  if [ -z "$http_code" ]; then
    err "No response from worker at $full_url"
    err "Are you logged in?  cloudflared access login --app=\"$worker_url\""
    cat "$tmp_body" >&2 || true
    return 1
  fi

  case "$http_code" in
    2??)
      cat "$tmp_body"
      return 0
      ;;
    401|403)
      err "Authentication failed (HTTP $http_code)."
      err "Log in once with:  cloudflared access login --app=\"$worker_url\""
      cat "$tmp_body" >&2 || true
      return 1
      ;;
    429)
      err "Rate limited (HTTP 429). Please wait a moment and try again."
      cat "$tmp_body" >&2 || true
      return 1
      ;;
    4??)
      err "Request rejected by worker (HTTP $http_code):"
      cat "$tmp_body" >&2 || true
      return 1
      ;;
    5??)
      err "Worker error (HTTP $http_code). Try again shortly or ping Siim."
      cat "$tmp_body" >&2 || true
      return 1
      ;;
    *)
      err "Unexpected response (HTTP $http_code):"
      cat "$tmp_body" >&2 || true
      return 1
      ;;
  esac
}
