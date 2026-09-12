#!/usr/bin/env bash
# Deploy the personal Claude Code skills. Run as your normal user (no sudo).
#
# Why a script and not stow: the target is ~/.claude/skills/, and `.claude/`
# is in .gitignore — a stow tree rooted at $HOME would have to fight that.
# Same reasoning as fontconfig/install.sh: one script owns the linking.
#
# What it does: symlinks each skills/<name>/ here to ~/.claude/skills/<name>,
# so editing a skill in the repo is live immediately — no re-install.
#
# An existing real directory is never deleted: it is moved aside into
# ~/.claude/skills/.backup-<timestamp>/ and the symlink takes its place.
# Idempotent: re-running only refreshes links that point elsewhere.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.claude/skills"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${DEST}/.backup-${STAMP}"

if [[ ${EUID} -eq 0 ]]; then
    echo "run as your normal user, not root — the target is \$HOME" >&2
    exit 1
fi

install -d "$DEST"

linked=0 skipped=0 moved=0

for dir in "$SRC"/*/; do
    name="$(basename "$dir")"
    [[ -f "$dir/SKILL.md" ]] || { echo "skip $name — no SKILL.md"; continue; }

    target="$DEST/$name"

    # Already pointing at us? Nothing to do.
    if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$dir")" ]]; then
        skipped=$((skipped + 1))
        continue
    fi

    # A real directory (or file) is preserved, never clobbered.
    if [[ -e "$target" && ! -L "$target" ]]; then
        install -d "$BACKUP"
        mv "$target" "$BACKUP/$name"
        echo "moved existing $name -> ${BACKUP}/$name"
        moved=$((moved + 1))
    else
        rm -f "$target"   # stale symlink pointing somewhere else
    fi

    ln -s "$dir" "$target"
    echo "linked $name"
    linked=$((linked + 1))
done

echo
echo "linked ${linked}, already current ${skipped}, backed up ${moved}"
echo "Verify:  ls -l ${DEST}"
echo "Then restart Claude Code, or start a new session, to pick the skills up."

if [[ $moved -gt 0 ]]; then
    echo
    echo "backup:   ${BACKUP}"
    echo "rollback: rm ${DEST}/<name> && mv ${BACKUP}/<name> ${DEST}/"
fi
