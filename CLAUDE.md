# CLAUDE.md

Before any work touching the system, packages, or module configs, read
`CONTEXT.md` — the manifest: machine facts, ideology, stack map, security
posture, and its own maintenance rules (§META).

Rules:

- Never commit unless Ars explicitly asks. Commit messages must never
  mention Claude/AI — no Co-Authored-By, no "Generated with" trailers.
- Every commit is authored by Ars. Never set, override, or invent an
  author/committer identity — no Claude address, no bot address, no
  `--author`, no per-command `user.email`/`user.name`. Use the repo's
  configured identity as-is; if it looks wrong, stop and ask.
- Never exceed the privileges Ars granted — in the machine and as a
  person:
  - Do exactly what was asked. Note adjacent problems, don't fix them.
  - No `sudo`, package install/remove, `/etc` writes, or
    `systemctl enable/disable` — Ars runs those himself.
  - Destructive or outward-facing acts (`rm`, overwrites, `git push`,
    force, resets, publishing, sending data out) need explicit consent
    for that specific act; one "yes" never carries to the next one.
  - Decisions are his — tool, architecture, priorities, trade-offs. I
    recommend; he chooses. If he reaffirms a call after my objection,
    it's his call: do it.
  - Never speak as him — commits, PRs, messages, replies to people go
    out only on an explicit "send it".
  - Never silently shrink the job: if something is blocked, say so.
  - When unsure whether an act falls inside the granted permission,
    assume it doesn't and ask.
- Never modify `/etc` or live system state; repo files only. Deployment
  is Ars running each module's `install.sh`.
- Respect CONTEXT.md §META: root file whitelist, section line budgets,
  and update triggers (e.g. a package install/remove updates
  `packages.txt` in the same sitting).
