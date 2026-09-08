---
name: syncing-machine-branches
description: Use when bringing one dotfiles machine branch up to date with the other (laniakea/celestia), when told configs or keybinds changed on the other machine, when asked what differs between the branches, when most of the diff looks like noise, or when asked to make the branches converge or to sync both directions at once
---

# Syncing machine branches

## Overview

`laniakea` (ThinkPad) and `celestia` (PC) are two branches of one dotfiles repo
with **no merge-base** — celestia was re-rooted. `git merge`, `cherry-pick` and
`rebase` between them do not work. Syncing is **file-by-file classification**,
never a merge.

Two jobs, not one:

1. **Move the portable subset.** The branches are *deliberately* different;
   much of the diff is machine reality, not drift.
2. **Kill the noise permanently.** A large share of the diff carries no
   information at all — the same comment naming a different checkout path.
   Fixing those files one by one is wasted work; fixing the *convention* means
   they never diverge again.

Measured once: a 106-file diff was 18 files of pure noise and another ~15 of
near-noise. It closed to 46, and the remainder was all hardware, paths and
per-branch files.

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
commits behind, touching the same files it had just synced. Measured cost of
running it: the local `celestia` was 9 commits stale.

**No exceptions:**
- Not when the local branch "was just updated"
- Not when the user says the other machine's changes are recent
- Not when a diff is only being *read* — a stale read produces a stale plan
- `git pull` on the current branch is NOT a fetch of the other branch

## Gate 2: measure the noise BEFORE reading any hunk

Do not open `git diff` and judge by eye. Extract both trees, substitute the
host/user/repo tokens in both, and re-diff. **Files that drop to zero are pure
noise** — they differ only by which machine's name is in them.

```sh
W=$(mktemp -d); mkdir -p "$W/a" "$W/b"
git archive HEAD            | tar -x -C "$W/a"
git archive origin/<other>  | tar -x -C "$W/b"

norm() { grep -rIl . "$1" | xargs -r sed -i -E \
  's#/home/(aru|segfault)#/home/USER#g;
   s#~/(dotfiles|celestia)#~/REPO#g;
   s#\b(laniakea|celestia)\b#HOST#g;
   s#\b(aru|segfault)\b#USER#g'; }
norm "$W/a"; norm "$W/b"

diff -rq "$W/a" "$W/b"          # what still differs = the real work
```

Then rank the residue by size — the line count *is* the classifier:

```sh
diff -rq "$W/a" "$W/b" | grep '^Files' |
  sed "s#^Files $W/a/##; s# and .*##" |
  while read -r f; do
    n=$(diff -u "$W/a/$f" "$W/b/$f" | tail -n +3 | grep -cE '^[+-]')
    printf "%4d  %s\n" "$n" "$f"
  done | sort -rn
```

| Residual lines | Almost always |
|---|---|
| 0 | noise, or identity-only (paths, polkit user, hostname on screen) |
| ≤ 8 | real paths and identity → leave alone |
| > 8 | real logic → read the hunks |

**Counting gotcha:** use `tail -n +3 \| grep -cE '^[+-]'`, not
`grep -cE '^[+-][^+-]'`. The second form silently misses every changed line in
Lua and Markdown (`-- comment` becomes `--- comment` in diff output), so files
report 0 residual when they have real changes.

## Gate 3: five buckets, not four

| Bucket | Test | Action |
|---|---|---|
| **Noise** | zero residual, and the name is only in prose/comments | Make identical — see the permanent fix |
| **Identity** | zero residual, but the value is *executed or displayed* | Leave. Exec paths, polkit `subject.user`, hostname on the lock screen |
| **Behind** | one side objectively newer, no machine content in the diff | Copy the whole file |
| **Machine delta** | encodes hardware, topology or user of that box | Leave. This is not drift |
| **Structural bug** | asymmetric *layout* — a file at a path only one side has | Fix. Collapses diff and repairs a broken install |

The fifth bucket is the one that hides. Two real finds:

- `rclone/etc/system/rclone-archive.service` — one path segment short of
  `etc/systemd/system/`, which is where `install.sh` reads from. Looked like
  "only on laniakea"; was actually a module that had never installed. In the
  same module, `rclone-sync.timer` was a byte copy of the `.service` with no
  `[Timer]` section at all.
- `xdg/applications/` on celestia — a stow package path, so it targets
  `~/applications`, not `~/.local/share/applications` where the desktop
  database looks. Three `.desktop` files were going nowhere.

**So: for every "only in X" file, check whether the module's `install.sh` or
stow target actually reads that path** before calling it a machine delta.

**Deletions on the other branch are not sync targets.** Files the other machine
removed (`power/`, `tlp/`, `Battery.qml`, `Wifi*.qml`, `Bt*.qml`) it removed
*because it lacks that hardware*. Applying the deletion here destroys working
config.

**Never sync:** `packages.txt` (regenerate with `pacman -Qqe` on this machine —
§META), `CONTEXT.md` §1/§5 (machine identity and deltas are per-branch),
`fish_variables`, `gtk-3.0/bookmarks`, anything under a `/home/<other-user>`
path.

**Also check the repo against the deployed system**, not just branch vs branch:

```sh
git status --short --ignored=no
```

A file can exist deployed in `~/.local/share/…` while being absent from the
repo, so a clean-machine deploy would break. Invisible in a branch-to-branch
diff. When found, prefer the **deployed** version if it is richer.

## The permanent fix for noise

Rewriting a noisy line to the other machine's wording just moves the diff.
Change the convention so neither machine's name appears:

| Was | Becomes |
|---|---|
| `see ~/dotfiles/PALETTE.md` | `see PALETTE.md` (repo-relative) |
| `cd ~/celestia && stow yazi` | `stow yazi   # from the repo root` |
| `# zathura on laniakea — …` | `# zathura — …` |
| `# can't traverse /home/segfault` | `# can't traverse $HOME` |
| `-- between celestia and the Mac` | `-- between the Linux machines and the Mac` |

The machine name survives in exactly two places: where it is **displayed**
(lock screen, greeter hostname strip) and where it is **executed** (Exec=
paths, `subject.user`, `--host`, systemd `User=`).

When a shared doc needs new wording for both sides, **write the text once and
copy it to both branches.** Do not edit one and port it — that produces a
second round of drift.

## Both directions in one session

The other machine is not uniformly ahead, and a one-direction pass means the
second pass re-derives all of this from scratch. Do both while the
classification is in hand.

Use a worktree for the other branch — never switch branches in the main tree,
which throws away uncommitted work:

```sh
git worktree add -b <sync-branch> "$SCRATCH/other-wt" origin/<other>
```

Both branches share one `.git`, so commits made in the worktree survive the
directory being deleted (`git worktree prune` afterwards). Say so when handing
off, especially if the worktree lives under `/tmp`.

Record who leads on what in `CONTEXT.md` §5 — the standing answer to "who is
ahead on what". It is per-branch, so it never gets copied across; write it on
both sides, each from its own point of view. Any module whose files you touched
also needs its §3 stack-map line updated in the same commit (§META).

## Before any `git add -A`

**Run `git status --short` first and read it.** The tree may hold work that is
not yours: the user editing in a parallel session, or a half-finished module.
Measured: a `git add -A` for a diff count staged a batch of the user's
uncommitted restic work; `git reset` (mixed, never `--hard`) put it back
without touching the tree.

Stage explicit paths when you know them. `git add -A` is for a tree you have
just read.

## Gate 4: plan, get decisions, then act

Present the buckets and stop. The ambiguous ones are the user's call, not a
judgment to make silently — hardware they may or may not own, features whose
symptom only they can confirm, docs that need rewriting vs copying, two
generations of the same generated artifact.

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
| nvim | `nvim --headless -c qa`; a copied file: `luajit -bl <path>` |
| quickshell | `qs log \| tail` after live-reload, then `qs ipc call <target> <fn>` |
| systemd units | `systemd-analyze verify <path>` |
| swayidle | `timeout 3 swayidle -w -C <path>` — parse errors print immediately |
| `*.desktop` | `desktop-file-validate <path>` |
| shell scripts | `bash -n <path>` |
| packages | `diff <(grep -v '^#\|^$' packages.txt \| sort) <(pacman -Qqe \| sort)` |

**Nothing on the other branch can be validated from here.** Its QML never runs,
its units never load, its stow never links. There is no `qmllint` on this box.
Say that as an explicit list, not as an assumed pass.

`nft -c -f` needs root for its cache and cannot check a repo copy — say so
rather than claiming the ruleset is verified.

## Deployment is the user's

Per CLAUDE.md: never modify `/etc` or live system state. Emit the exact
commands (`sudo <module>/install.sh`, `stow <pkg>`) and stop.

Flag stow conflicts in advance: a file that currently exists as a **real file**
where stow wants a symlink will fail. Say which file and that contents match.

## Red flags — stop

- About to read a diff and `git fetch` has not run this session
- Comparing `<other>` instead of `origin/<other>`
- About to read hunks before the normalizing diff has run
- Reaching for `merge`, `cherry-pick`, `rebase`, or `git merge-base` output being empty is a surprise
- About to apply a deletion the other branch made
- Calling an "only in X" file a machine delta without checking `install.sh`
- Copying `packages.txt` or `CONTEXT.md` wholesale
- `git add -A` without having read `git status` this turn
- Editing on `laniakea`/`celestia` directly, or `git switch` in the main tree
- Syncing one direction and calling the job done
- Reporting "готово" with untested items folded in silently

## Rationalizations

| Excuse | Reality |
|---|---|
| "Local branch is probably current" | It was 9 commits stale in the last measured case. Fetch costs a second. |
| "I'm only reading the diff" | A stale read produces a stale plan and a stale commit. |
| "The diff is huge, I'll classify as I go" | Classification after editing means machine values already landed. Measure first — it splits the work in half. |
| "This file looks clean" | Run the normalizing diff, don't look. `~/celestia` hides in one comment line. |
| "The comment names the other machine, so it's a machine delta" | A comment is not executed. If the name is neither displayed nor run, it is noise. |
| "It's only in X, so they deleted it" | Or it sits at the wrong path on your side and the module has never installed. Check `install.sh`. |
| "They deleted it, so it's dead" | They deleted it because they have no battery. You do. |
| "I'll do the other direction later" | Later has none of this context and re-derives all of it. |
| "Both machines should converge fully" | They shouldn't. §5 exists because the deltas are intentional. |
