---
description: Package a local skill and open a PR to share it with the team.
---

# /skill-publish

Packages a skill directory (markdown-only in v1) and opens a pull request
against Begin's team skills repo for review. Authenticates to the skills worker
via Cloudflare Access (Google SSO). Re-running on the same skill updates the
same PR — it is idempotent. Siim reviews and merges; merged skills reach
everyone via `/skill-sync`.

Run the bundled script, passing the skill directory (defaults to the current
directory if omitted):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/skill-publish.sh" /path/to/my-skill
```

The directory name becomes the skill name. If the directory contains any
non-`.md` file, publishing is refused (v1 supports markdown only).
