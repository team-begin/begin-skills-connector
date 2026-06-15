---
description: Install or update Begin's reviewed team Claude Code skills.
---

# /skill-sync

Pulls the team's vetted Claude Code skills onto this machine. It fetches a
short-lived GitHub read token from Begin's skills worker (Google SSO via
Cloudflare Access), points the `claude` CLI at the private marketplace, updates
it, and installs the skills. You always get the reviewed `main` versions — your
own local edits are never overwritten.

Run the bundled script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/skill-sync.sh"
```

If you have never authenticated on this machine, run once first:

```bash
cloudflared access login --app="$BEGIN_SKILLS_WORKER_URL"
```
