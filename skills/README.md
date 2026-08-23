# skills/

Personal Claude Code skills written for this repo's own workflows. Each
subdirectory is one skill; Claude reads them from `~/.claude/skills/`.

## Deploy

```sh
~/dotfiles/skills/install.sh      # no sudo — target is $HOME
```

Symlinks each `skills/<name>/` to `~/.claude/skills/<name>`, so editing a
skill here is live with no re-install. An existing real directory is moved
into `~/.claude/skills/.backup-<timestamp>/` rather than deleted.

Skills are picked up at session start — restart Claude Code after linking a
new one.

## Current skills

| Skill | Fires when |
|---|---|
| `auditing-machine-state` | Checking or refreshing the docs against the actual machine; asking what drifted; asking what can be deleted |
| `syncing-machine-branches` | Bringing `laniakea` and `celestia` into line; asking what differs between the branches |

## Adding one

```
skills/<verb-first-name>/SKILL.md
```

Frontmatter needs exactly `name` and `description`. The description is
**trigger conditions only** — start it with "Use when…" and do not summarise
the skill's steps there, or Claude will act on the summary instead of reading
the body.

Name by the action (`auditing-…`, `syncing-…`), not by the topic.
