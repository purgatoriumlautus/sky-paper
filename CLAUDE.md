# CLAUDE.md

Before any work touching the system, packages, or module configs, read
`CONTEXT.md` — the manifest: machine facts, ideology, stack map, security
posture, and its own maintenance rules (§META).

Rules:

- Never commit unless Ars explicitly asks. Commit messages must never
  mention Claude/AI — no Co-Authored-By, no "Generated with" trailers.
- Never modify `/etc` or live system state; repo files only. Deployment
  is Ars running each module's `install.sh`.
- Respect CONTEXT.md §META: root file whitelist, section line budgets,
  and update triggers (e.g. a package install/remove updates
  `packages.txt` in the same sitting).
