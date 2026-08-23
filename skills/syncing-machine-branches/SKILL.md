---
name: syncing-machine-branches
description: Use when bringing one dotfiles machine branch up to date with the other (laniakea/celestia), when told configs or keybinds changed on the other machine, or asked what differs between the branches
---

# Syncing machine branches

## Overview

`laniakea` (ThinkPad) and `celestia` (PC) are two branches of one dotfiles repo
with **no merge-base** — celestia was re-rooted. `git merge`, `cherry-pick` and
`rebase` between them do not work. Syncing is **file-by-file classification**,
never a merge.

The branches are *deliberately* different. Most of the diff is machine reality,
not drift. The job is to find the portable subset and move only that.

## Gate 1: fetch, or everything after is wrong

**Run `git fetch origin` before reading a single diff. Compare against
`origin/<other>`, never the local tracking branch.**

```sh
git fetch origin
git log --oneline -1 <other> origin/<other>   # do they differ?
git rev-list --count <other>..origin/<other>  # how stale is local?
```

The local copy of the other machine's branch is only as fresh as the last time
someone typed `git fetch` here — which may be months. A skipped fetch is
invisible: every diff, every classification and every commit downstream looks
correct and is silently built on stale input.

Measured cost of skipping it once: a completed 6-commit sync was already 4
commits behind, touching the same files it had just synced.

**No exceptions:**
- Not when the local branch "was just updated"
- Not when the user says the other machine's changes are recent
- Not when a diff is only being *read* — a stale read produces a stale plan
- `git pull` on the current branch is NOT a fetch of the other branch

## Gate 2: audit before proposing anything

Read every changed file. Put each into exactly one bucket:

| Bucket | Meaning | Action |
|---|---|---|
| **Portable** | 0 machine-specific values (`grep` proves it) | `git checkout origin/<other> -- <path>` |
| **Mixed** | Portable change + machine values in one file | Hand-merge, take only the portable hunks |
| **Machine delta** | Encodes hardware/topology/user of the other box | Leave alone. This is not drift. |
| **Never sync** | Regenerated locally, not copied | See list below |

**Required grep gate before calling anything portable:**

```sh
grep -rnE 'segfault|/home/aru|~/celestia|~/dotfiles|DP-[0-9]|eDP-1|sync-ws' <paths>
```

Non-empty output means the file is Mixed, not Portable — no matter how clean
the change looks.

**Deletions on the other branch are not sync targets.** Files the other machine
removed (`power/`, `tlp/`, `Battery.qml`, `Wifi*.qml`, `Bt*.qml`) it removed
*because it lacks that hardware*. Applying the deletion here destroys working
config. Classify deletions like everything else.

**Never sync:** `packages.txt` (regenerate with `pacman -Qqe` on this machine —
§META), `CONTEXT.md` §1/§5 (machine identity and deltas are per-branch),
`fish_variables`, `gtk-3.0/bookmarks`, anything under a `/home/<other-user>`
path.

**Also check the repo against the deployed system**, not just branch vs branch:

```sh
# is something referenced by tracked config but itself untracked?
git status --short --ignored=no
```

A file can exist deployed in `~/.local/share/…` while being absent from the
repo, so a clean-machine deploy would break. This class of gap is invisible in
a branch-to-branch diff. When found, prefer the **deployed** version if it is
richer than the other branch's tracked copy.

## Gate 3: plan, get decisions, then act

Present the buckets and stop. The ambiguous ones are the user's call, not a
judgment to make silently — hardware they may or may not own, features whose
symptom only they can confirm, docs that need rewriting vs copying.

Then: work on a branch off the current one, never on `laniakea`/`celestia`
directly (see the no-commits-on-user-branch rule). Rewrite paths with `sed`
after copying. Validate. Hand deployment over.

## Validate every touched module before handing off

| Module | Command |
|---|---|
| niri | `niri validate -c <path>` |
| tmux | `tmux -L test -f <path> new-session -d 'sleep 5'` (isolated socket) |
| fish | `fish -c 'source <path>'` |
| kitty | `kitty +runpy 'from kitty.config import load_config; load_config("<path>")'` — 0.48.2 has **no** `--debug-config` |
| nvim | `nvim --headless -c qa` |
| quickshell | `qs log \| tail` after live-reload, then `qs ipc call <target> <fn>` |
| `*.desktop` | `desktop-file-validate <path>` |
| shell scripts | `bash -n <path>` |
| packages | `diff <(grep -v '^#\|^$' packages.txt \| sort) <(pacman -Qqe \| sort)` |

Say plainly what could not be verified. Keyboard focus, key delivery and
anything needing `/etc` cannot be tested from here — those go to the user as an
explicit list, not as an assumed pass.

## Deployment is the user's

Per CLAUDE.md: never modify `/etc` or live system state. Emit the exact
commands (`sudo <module>/install.sh`, `stow <pkg>`) and stop.

Flag stow conflicts in advance: a file that currently exists as a **real file**
where stow wants a symlink will fail. Say which file and that contents match.

## Sync runs both directions

The other machine is not uniformly ahead. Before finishing, list what *this*
branch leads on so it can go back the other way. Record the direction per area
in `CONTEXT.md` §5 — that section is the standing answer to "who is ahead on
what", and it is per-branch, so it never gets copied across.

## Red flags — stop

- About to read a diff and `git fetch` has not run this session
- Comparing `<other>` instead of `origin/<other>`
- Reaching for `merge`, `cherry-pick`, `rebase`, or `git merge-base` output being empty is a surprise
- About to apply a deletion the other branch made
- Copying `packages.txt` or `CONTEXT.md` wholesale
- Calling a file portable without having grepped it
- Editing on `laniakea`/`celestia` directly
- Reporting "готово" with untested items folded in silently

## Rationalizations

| Excuse | Reality |
|---|---|
| "Local branch is probably current" | It was 4 commits stale in the one measured case. Fetch costs a second. |
| "I'm only reading the diff" | A stale read produces a stale plan and a stale commit. |
| "The diff is huge, I'll classify as I go" | Classification after editing means machine values already landed. |
| "This file looks clean" | Grep, don't look. `~/celestia` hides in one comment line. |
| "They deleted it, so it's dead" | They deleted it because they have no battery. You do. |
| "Both machines should converge fully" | They shouldn't. §5 exists because the deltas are intentional. |
