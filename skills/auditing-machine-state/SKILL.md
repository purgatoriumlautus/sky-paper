---
name: auditing-machine-state
description: Use when asked to check or refresh the repo's docs against the actual machine, when a manifest's Verified stamp looks stale, when asked what drifted, or when asked what packages, caches, files or junk can be deleted
---

# Auditing machine state

## Overview

A dotfiles repo makes **claims** — about hardware, about which modules exist,
about what is deployed, about which packages earn their place. Claims decay
silently: nothing errors when the CPU line is wrong or a module grows an
`install.sh` the stack map never learned about.

An audit is not reading the docs. **An audit re-derives every claim from a live
probe and reports the delta.** If you did not run a command that could have
contradicted a line, you did not check that line.

Nothing here modifies live state. The output is a report plus a proposal.

## Gate 0: discover the machine, never assume it

This skill runs on more than one box. Hardcoding any name is the failure mode.

```sh
REPO=$(git rev-parse --show-toplevel)
HOST=$(uname -n)
BRANCH=$(git branch --show-current)      # may be a work branch, not the machine branch
ls "$REPO"                                # the doc set is whatever is actually there
```

- **Machine identity comes from `$HOST`, not from `$BRANCH`.** You can be on a
  feature branch, or on the *other* machine's branch by accident. Check.
- **The doc set is discovered, not remembered.** Some machines carry
  `PALETTE.md`, some don't. Audit the files that exist.
- **The manifest declares its own rules.** If it has a §META (root whitelist,
  section budgets, update triggers, drift check), those are the rules for *this*
  branch. Never import budgets or whitelists remembered from the other machine.
- **Detect the package manager**, don't assume: `pacman` / `apt` / `dnf` /
  `brew`. Every package command below is written for pacman; substitute by role
  (explicit list / orphans / reverse-deps / cache dir), and say so in the report.

## Gate 1: docs → reality

Read each doc and extract its **falsifiable claims**. For every claim, run
something that could disprove it. Claims with no probe are not audited — say so
rather than passing them.

| Claim class | Probe |
|---|---|
| CPU / RAM / GPU / disk | `lscpu`, `free -h`, `lspci`, `lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT`, `swapon --show` |
| Laptop battery, thresholds | `cat /sys/class/power_supply/BAT*/{model_name,manufacturer,energy_full_design,energy_full,cycle_count,charge_control_*_threshold}` |
| Display / outputs | the compositor config + `hostnamectl`; never trust a remembered resolution |
| Network hardware & stack | `lspci \| grep -i net`, `systemctl is-enabled/is-active` per daemon, and the daemon's own config for a **backend** setting |
| Login shell, boot flow | `getent passwd "$USER"`, `systemctl is-enabled <display-manager>` |
| "module X does Y" | read module X's files — not its README |
| "module X is stow / install.sh" | `ls <module>` — an `install.sh` or a non-`.config` top-level dir means it is not a plain stow package |
| Keybind / option values quoted in docs | `grep -n` the actual config for that exact bind |
| Fonts, sizes | the config that sets them, not the doc that describes them |
| Colors / theme values | see Gate 4 |

**Enumerate modules, never recite them:**

```sh
for d in "$REPO"/*/; do
  printf '%s\t' "${d%/}"
  find "$d" -maxdepth 3 -type f | head -40 | tr '\n' ' '; echo
done
```

Then check each against the stack map: modules present but undocumented,
documented but gone, and modules whose deploy mechanism the doc gets wrong.

**Enforce the manifest's own §META** while you are there — it is the one rule
set that audits itself and therefore never gets audited. Count section lines
against the stated budgets, check the root file whitelist, check `Verified:`
stamps against the newest change to each section's related files. A long-lived
budget breach is a real finding.

## Gate 2: reality → docs

Gate 1 finds wrong lines. It cannot find **missing** ones — a doc that never
mentions a thing is internally consistent. Sweep the other direction:

```sh
systemctl list-unit-files --state=enabled --no-pager      # enabled but undocumented?
systemctl --failed --no-pager
ls ~/.config ~/.local/share ~/.local/bin                   # deployed but untracked?
```

Anything running, enabled, or deployed that no doc accounts for is a finding —
especially when it **contradicts a stated posture** ("no containers here" while
a container socket is enabled). Contradicted posture outranks a wrong CPU model:
report it first.

Sweep the repo's own state in the same pass — it drifts as quietly as the docs:

```sh
git status --short                      # untracked files nobody decided about
git log --oneline @{u}..HEAD            # work that exists only on this disk
git branch --merged                     # branches whose work already landed
git branch -vv                          # which have upstreams, which are local-only
```

Untracked files in a module are a finding in their own right: they are usually
scratch notes or a half-finished doc that the manifest's own banned-content rule
would reject. Read one before proposing anything about it — a "TODO" file whose
steps are all done is dead, but only reading it proves that.

## Gate 3: repo → live deployment drift

The repo says what *should* be deployed. Compare against what *is*.

```sh
# root-owned drop-ins: does the live filename still match the repo's?
ls /etc/<dir>.d/ ; ls "$REPO"/<module>/etc/<dir>.d/

# stow links: does each land back in the repo?
for d in ~/.config/*; do printf '%-24s %s\n' "$(basename "$d")" "$(readlink -f "$d")"; done
```

A repo file renamed without re-running its `install.sh` leaves the **old name
live**. This is invisible in `git status` and invisible in a doc read. The
symptom is a doc sentence that explains an ordering or precedence which no
longer holds.

A `~/.config/<x>` that resolves to itself is not broken — stow falls back to
per-file links when the directory already exists. Check one level deeper before
calling it a finding.

## Gate 4: theme / palette values, both directions

If the repo has a palette doc, it is a claim set like any other. Collect every
value from the doc and from every themed config, then diff **both ways**.

```sh
grep -ohiE '#[0-9a-fA-F]{6,8}\b' PALETTE.md | tr 'a-f' 'A-F' | sort -u > /tmp/doc.txt
grep -rohiE '#[0-9a-fA-F]{6,8}\b' <config paths> | tr 'a-f' 'A-F' | sort -u > /tmp/live.txt
comm -23 /tmp/doc.txt /tmp/live.txt   # doc claims a value nothing uses  → phantom
comm -13 /tmp/doc.txt /tmp/live.txt   # config uses a value doc omits    → undocumented
```

- **Match the whole token.** A 6-char pattern splits `#BF1C1B1A` (ARGB) into a
  fake mismatch. Use `{6,8}` and `\b`, then read every hit before reporting it.
- **Commented-out stock config is not drift.** Filter `^\s*(//|#)` before
  concluding a stray value is in use.
- **A doc can be right about hex and wrong about everything else** — fonts,
  sizes, whether a widget has a background at all. Check the non-color claims
  in the same pass.
- Values expressed in another space (256-palette indices, named colors) will
  never match a hex grep. Find them by reading the config, and record the
  mapping rather than deleting the section.

## Gate 5: packages — a clean drift check is not a clean audit

Run the manifest's own drift check first (usually list-vs-live). **Passing it
proves only that the file was regenerated.** It says nothing about whether the
packages belong. Three separate questions:

```sh
diff <(grep -v '^#\|^$' packages.txt | sort) <(pacman -Qqe | sort)   # 1. manifest fresh?
pacman -Qtdq                                                         # 2. orphans
pacman -Qqe                                                          # 3. earns its place?
```

For **3**, grep the repo for each name and read the hits:

```sh
grep -rli --exclude-dir=.git --exclude=packages.txt "<pkg>" "$REPO"
```

- **Read every hit.** Short names match inside unrelated words and inside
  filenames. A hit is a reference only if it is a real reference.
- **Hits only in historical design docs = no reference.** Old plans mention
  tools that were replaced.
- **Two packages filling one role is the finding** (two notification daemons,
  two file managers, two bars). One of them is the stack; the other is residue.
- **Before proposing any removal, verify reverse-deps and current version:**
  `pacman -Qi <pkg> | grep -E 'Required By|Installed Size'`. A scary-looking
  orphan is often genuinely dead because its consumer moved to a newer variant —
  confirm which, don't guess.
- **Removing a package fires the manifest's update trigger.** Regenerating the
  package list is part of the removal, in the same sitting.

## Gate 6: caches and junk

Measure, don't estimate. Sort by size and stop at the point where it stops
mattering.

```sh
df -h /
du -sh ~/* 2>/dev/null | sort -rh | head -20
du -sh ~/.cache/* 2>/dev/null | sort -rh | head -20
du -sh /var/cache/<pkgmgr>/* 2>/dev/null | sort -rh | head
journalctl --disk-usage
```

Recurring classes worth naming explicitly:

| Class | Note |
|---|---|
| Package manager cache | Distinguish *stale* entries (for uninstalled pkgs) from current ones — the current ones are the downgrade path |
| Source/build trees in `$HOME` | Compare the built version against the installed one; equal means the tree is dead weight |
| AUR/helper caches | Fully regenerable |
| Language toolchains (npm, go, pip, cargo) | Regenerable; each has its own `clean` command |
| Editor plugin + LSP dirs | **Not junk by default** — these are live installs. Only unused servers are junk, and that needs reading the config |
| Config dirs of removed packages | Orphan only *after* the package goes |
| Trash, coredumps, journal | Bounded by config; check the cap before proposing a manual purge |

State what a path *is* before proposing its deletion. A large directory is not
evidence of garbage.

## Gate 7: propose, do not execute

Sort every proposal by **reversibility**, and say which tier each is in:

| Tier | Contents | Handling |
|---|---|---|
| 1 — regenerable | caches, build trees, stale pkg cache | safe to propose outright |
| 2 — reinstallable | packages, with sizes and reverse-dep check shown | propose with the exact command |
| 3 — unique or unrecoverable | untracked files, repos with unique history, branches, anything not pushed | **name the risk and stop**; never fold into "all" |

Before proposing a directory that looks like a superseded copy, prove it is
recoverable: does it have a remote, is `HEAD` pushed, is its history reachable
from the repo that replaced it. Unproven means Tier 3.

**Check the project's own rules for whether you may touch live state at all.**
If `CLAUDE.md`/`AGENTS.md` says repo-files-only, emit the commands and hand off
rather than running them. If a command needs a password you do not have, say so
immediately instead of discovering it mid-cleanup — offer the command for the
user to run in their own shell.

**"Delete everything" does not include Tier 3, and does not answer a question
you flagged as the user's call.** Re-confirm those individually.

Finally: **re-measure before deleting.** Between the audit and the go-ahead the
user may have cleaned some of it themselves. Report what is already gone rather
than claiming credit or acting on a stale list.

## Gate 8: rewriting a doc after the audit

Auditing produces a delta; refreshing the doc is a separate job with its own
failure modes. Back up first (`cp <doc> <scratch>/`), then:

**Per-section, not whole-file.** A `Verified:` stamp covers one section. Bump
only the sections you actually re-derived. Bumping a stamp you did not probe is
worse than leaving it stale — it launders an unverified claim as fresh.

**A budget breach is fixed by cutting, never by raising the budget.** If the
manifest says a section gets N lines and it has more, compress prose until it
fits. Preserve every load-bearing invariant verbatim in meaning; drop
connective tissue, not rules.

**Cut the classes the manifest bans.** Recurring ones: narration and history
("fourth iteration", "X → Y → Z", "this used to be"), comparisons against
replaced designs, "now really", "as before", "unchanged", todos, version
numbers, links to transition-design docs. Keep the *rule* a historical
sentence was carrying and delete the history around it.

**Duplicated sections hide in long docs.** Two blocks describing the same tool
under different headings both look correct in isolation. Merge them.

**Prove nothing was lost.** Diff the extractable values before and after:

```sh
comm -23 <(grep -ohiE '<pattern>' "$BAK" | sort -u) <(grep -ohiE '<pattern>' "$DOC" | sort -u)
```

Every dropped value must be one you deliberately removed and can name. Then
**re-run the audit gate for that doc** — the rewrite is only done when the
both-directions check comes back clean.

**Prose that carries the user's voice is not yours to rewrite silently.**
Ideology, rationale, naming — if a fix requires reworking those, do it, then
say explicitly in the report that you touched wording rather than facts, so it
can be reverted independently of the factual corrections.

**Adding a file or directory to the repo root fires the manifest's whitelist
rule.** Update the whitelist in the same change, or the next audit flags what
you just added.

## Red flags — stop

- Reciting a doc's claim back as verified without a command behind it
- Using a machine name, module list, or budget from memory instead of from `$REPO`
- Reading `git status` clean and concluding nothing drifted — deployment drift and doc drift are both invisible there
- A passing package drift-check treated as a finished package audit
- Calling a package unused after grepping but before reading the hits
- Proposing removal of an orphan without checking reverse-deps and its consumer's current version
- Proposing deletion of a path whose contents you never listed
- Folding a Tier 3 item into a batch because the user said "all"
- Reporting sizes gathered before the user's own cleanup
- Bumping a `Verified:` stamp on a section you did not probe
- Raising a budget instead of cutting to fit it
- Rewriting a doc without a backup and without a before/after value diff
- Adding something to the repo root without updating the whitelist

## Rationalizations

| Excuse | Reality |
|---|---|
| "The Verified stamp is recent" | Stamps are written by hand and lie. The probe costs seconds. |
| "The drift check passed" | It proves the file was regenerated, not that the contents belong. |
| "This doc section never changes" | The section nobody audits is where the budget breach lives. |
| "Grep found the package name" | Grep found a substring. Read the hit. |
| "It's an orphan, so it's dead" | Confirm which consumer dropped it and what replaced it. |
| "Big directory, must be junk" | Say what it is first. LSP servers and plugin dirs are live installs. |
| "The user said delete everything" | They said that before you told them one item was unrecoverable. |
| "I'll just run the sudo part" | Check the project rules and your actual privileges first, not mid-cleanup. |
| "I measured this an hour ago" | Re-measure. The user has a shell too. |
| "I rewrote the section, so the stamp is current" | The stamp means *probed*, not *edited*. |
| "The section is over budget but it's all useful" | Then compress it. The budget is the rule; your judgment isn't. |
| "It's just prose, I'll tighten it" | Say that you touched wording, so facts and voice can be reverted separately. |
| "The diff looks fine" | Diff the extracted values, not your impression of the diff. |
