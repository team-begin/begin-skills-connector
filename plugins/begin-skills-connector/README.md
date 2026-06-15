# Begin Skills Connector

A Claude Code plugin that lets Begin employees share team skills with two slash
commands:

- **`/skill-sync`** — install or update the team's reviewed Claude Code skills.
- **`/skill-publish`** — package a local skill and open a PR for review.

This plugin contains **no secrets**. It only calls an authenticated Begin
backend (a Cloudflare Worker behind Cloudflare Access / Google SSO). The worker
holds the GitHub credentials; you authenticate with your Begin Google account.

## Prerequisites

You need these installed and on your `PATH`:

- [`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) — Google SSO auth from the CLI
  - macOS: `brew install cloudflared`
- [`jq`](https://jqlang.github.io/jq/) — JSON parsing
  - macOS: `brew install jq`
- `curl` — usually preinstalled
- The [Claude Code CLI](https://docs.anthropic.com/claude-code) (`claude`)

## One-time setup

1. Find the worker URL (ask Siim) and make it available to the scripts, either:

   ```bash
   export BEGIN_SKILLS_WORKER_URL="https://<worker-url>"
   ```

   or write it to a config file (a single line containing the URL):

   ```bash
   mkdir -p ~/.config/begin-skills
   printf '%s\n' "https://<worker-url>" > ~/.config/begin-skills/config
   ```

2. Log in once with your Begin Google account:

   ```bash
   cloudflared access login --app="$BEGIN_SKILLS_WORKER_URL"
   ```

   This opens a browser for Google SSO. After this, the scripts attach your
   identity automatically via `cloudflared access curl`.

## Usage

### Install / update team skills

```
/skill-sync
```

Fetches a short-lived GitHub read token from the worker, updates the private
marketplace, and installs the skills. You always get the reviewed `main`
versions; your local edits are never overwritten.

### Publish a skill for review

```
/skill-publish /path/to/my-skill
```

(Defaults to the current directory if no path is given.) The directory name
becomes the skill name. All `*.md` files are packaged and a PR is opened against
`team-begin/begin-skills`. Re-running on the same skill updates the **same** PR
— it is idempotent. Siim reviews and merges; merged skills then reach everyone
via `/skill-sync`.

> v1 supports **markdown-only** skills. If the directory contains any non-`.md`
> file, publishing is refused.

## How it works

| Command | Worker endpoint | Effect |
| --- | --- | --- |
| `/skill-sync` | `GET /token` | Returns a short-lived GitHub read token; the `claude` CLI uses it to add/update the marketplace and install skills. |
| `/skill-publish` | `POST /publish` | Sends the skill's markdown files; the worker commits them to a branch and opens/updates a PR. |

## Troubleshooting

- **Auth failed (401/403):** re-run `cloudflared access login --app="$BEGIN_SKILLS_WORKER_URL"`.
- **`cloudflared: command not found`:** install it (`brew install cloudflared`). Scripts fall back to plain `curl`, but without your Google identity the worker will reject the request.
- **`jq: command not found`:** install it (`brew install jq`).
- **Rate limited (429):** wait a moment and retry.
- **Placeholder URL warning:** you have not set `BEGIN_SKILLS_WORKER_URL` or the config file — set the real worker URL (see One-time setup).
