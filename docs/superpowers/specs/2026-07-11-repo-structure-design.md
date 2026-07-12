# Repo Structure & CONTEXT.md Redesign — Design Spec

Date: 2026-07-11
Scope: both repos — `celestia` (PC) and `laniakea` (ThinkPad X280; live copy is `~/dotfiles` on the laptop)
Status: awaiting user review

## Goal

A clean, converged two-repo layout with a single rich manifest per repo
(CONTEXT.md) that Claude reads on demand to refresh system knowledge —
machine facts, ideology, stack, security posture — and that documents its
own maintenance rules so it cannot rot the way laniakea's 408-line journal
did.

## Decisions (all confirmed by Ars)

1. CONTEXT.md structure: **Option A — single layered manifest**, same
   skeleton in both repos.
2. Loading: tiny repo `CLAUDE.md` auto-loads and points Claude at
   CONTEXT.md before any system work. CONTEXT.md itself is on-demand.
3. Root layout: **Option 1 — flat, one dir per module, plus a hard
   whitelist** of root files, identical in both repos.
4. `todos.*`: **deleted** from both repos. Live tasks move to Obsidian or
   an untracked scratchfile. Not on the whitelist.
5. `README.md`: kept, tiny (what the repo is, screenshot, deploy in three
   commands). Celestia gets one; screenshots move to `docs/screenshots/`.
6. `packages.txt`: kept in both repos (laniakea gets one for the first
   time). **Names only** (`pacman -Qqe` format, no versions).
   Freshness: **Mechanism 1 — manual + documented drift check** (no pacman
   hook). The drift one-liner lives in CONTEXT.md §META; rule: any
   install/remove updates the file in the same sitting.
7. `bin/`: root citizen in both repos; laniakea's `pd-bt` is ported to
   celestia.
8. laniakea `.gitignore`: stops ignoring `CONTEXT.md` (and `docs/` once
   cleaned) so the manifest and screenshots are committed and can converge.

## Root whitelist (identical in both repos)

Module directories, plus exactly:

- `README.md` — 30-second human orientation + screenshot links
- `CLAUDE.md` — pointer: "read CONTEXT.md before system work" + repo-local
  Claude rules (read-only-by-default, no commits, teaching-mode waiver)
- `CONTEXT.md` — the manifest (structure below)
- `PALETTE.md` — Sky Paper color source of truth (referenced by QML/CSS)
- `packages.txt` — explicit package names, no versions
- `.gitignore`
- `bin/` — user scripts deployed by symlink or PATH entry
- `docs/` — `screenshots/`, design specs; nothing load-bearing

Anything else at root is a violation: it moves into a module, into
`docs/`, or gets deleted. This rule is written into CONTEXT.md §META.

## CONTEXT.md skeleton (Option A)

Sections in order of how often Claude needs them. Each section carries its
own `Verified: YYYY-MM-DD` stamp and a line budget; breaching the budget
means trimming before committing, not raising the budget.

1. **Machine identity** (budget ~12 lines) — hostname, user, repo path,
   hardware, role. The only section allowed to differ between repos apart
   from §5.
2. **Ideology** (~12 bullets) — minimalism doctrine; the three package
   questions (simpler alternative? removable? replaceable by something
   already present?); Sky Paper invariants; CLI-first, zero-distraction;
   "no daemon a script can replace".
3. **Stack map** (~1 line per module) — module → what it is → deploy
   method (stow | install.sh) → where it lands. No prose. Ends with a
   short **Packages** subsection: pointer to packages.txt as the
   authoritative list, plus why-annotations for non-obvious keepers only.
4. **Security posture** (~30 lines) — deltas from Arch defaults only:
   sshd drop-in (00-hardening.conf, first-obtained-value-wins), nftables
   policies (incl. forward-policy difference and why), sysctl pins. Every
   fact paired with the shell command that verifies it live.
5. **Machine deltas** (~15 lines) — the honest fork list: ip_forward,
   forward policy, battery/TLP modules, hardware-specific bits.
6. **§META — maintenance rules** (~25 lines):
   - the root whitelist (above);
   - per-section line budgets and the trim-don't-grow rule;
   - update trigger: "changed a module → update its CONTEXT.md line in
     the same commit"; "installed/removed a package → update packages.txt
     in the same sitting";
   - the packages drift check one-liner (diff of sorted packages.txt names
     vs `pacman -Qqe`), to run at the start of any repo work session;
   - banned content: history/narration (→ git log), todos (→ Obsidian),
     how-to walkthroughs (→ module READMEs), package versions;
   - `Verified:` stamps are per-section; a stamp older than the section's
     newest related file change means the section is suspect.

Language: converged sections are written in English so the two files diff
cleanly (celestia's is already mostly English). Machine-identity/deltas
prose may be terse; no mixed-language sections.

## Migration / cleanup steps

Per repo unless noted. Order matters only where stated.

1. laniakea: archive the current CONTEXT.md journal content to
   `docs/journal-2026.md` (kept, untracked or tracked — Ars decides at
   implementation), then rewrite CONTEXT.md to the Option A skeleton.
2. celestia: restructure existing CONTEXT.md into the same skeleton
   (content mostly survives; it is already manifest-shaped).
3. Strays:
   - `celestia/mimeapps.list` → new `xdg/` stow module
     (`xdg/.config/mimeapps.list`).
   - `celestia/hadnoff.txt`, `laniakea/firefoxtheme.txt` → read, salvage
     any still-true facts into CONTEXT.md or module READMEs, delete.
   - `celestia/todos.md`, `laniakea/todos.txt` → salvage live items to
     Obsidian, delete.
   - `laniakea/screenshots/` → `laniakea/docs/screenshots/`; README links
     updated.
   - `celestia/xfce4/` → fossil check at implementation time: if nothing
     on the niri stack reads it, delete (P2 decision, Ars calls it).
4. packages.txt: regenerate celestia's from `pacman -Qqe` (names only) —
   note this legitimizes `postgresql` and `tealdeer`; Ars confirms each
   survivor against the three package questions first. Generate
   laniakea's on the laptop itself (this repo copy can carry a placeholder
   header until then).
5. `bin/`: port `pd-bt` to celestia (verify its JACK/Pd deps exist on the
   PC first); decide deploy mechanism (stow-style symlink into
   `~/.local/bin` or PATH addition in fish config) — same mechanism both
   repos.
6. New tiny `CLAUDE.md` in both repos (same content, parameterized only
   by repo name if at all).
7. New tiny `README.md` for celestia; trim laniakea's to the same shape.
8. laniakea `.gitignore`: remove `CONTEXT.md`, `docs/`; keep ignoring
   tmux plugins and `.claude/`.
9. Both repos: run the packages drift check and stray-scan (`ls -A` root
   vs whitelist) as the final verification.

## Non-goals

- No changes to module contents, `/etc`, or live system state.
- No git commits by Claude — Ars reviews and commits everything.
- Convergence of module *internals* (niri config, quickshell, greeter
  sync direction) stays in the audit checklist (P3), not this spec.

## Open items deferred to implementation

- `xfce4/` keep-or-delete (needs live-usage check).
- Whether `docs/journal-2026.md` is tracked or untracked on laniakea.
- `postgresql` / `tealdeer` package-question review before they enter the
  regenerated packages.txt.
