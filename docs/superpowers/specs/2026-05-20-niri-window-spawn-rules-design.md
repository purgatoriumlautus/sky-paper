# niri window-spawn rules — design

Date: 2026-05-20
Branch: `niri-popup-float`
Todo: `todos.txt` #3

## Problem

Two related spawn-behavior gaps observed in niri 26.04:

1. **Firefox OAuth popups open tiled, half-screen.** Sites like Gmail / GitHub /
   Atlassian spawn login windows via `window.open(url, name, "features=…")`.
   These share `app_id=firefox` with the main browser, so niri places them as
   normal tiled siblings — a half-width "popup" instead of a centered dialog.

2. **Cross-app focus is intermittent.** Clicking a URL in kitty calls
   `xdg-open` → firefox. Sometimes focus follows; sometimes it doesn't.
   Reproduction is unreliable, so we want a preemptive safety net rather
   than a targeted fix.

## Audit of related concerns

The original `todos.txt` #3 entry bundled three concerns. The audit (2026-05-20)
showed two are already satisfied by niri defaults:

| Scenario                              | Status            | Why                                              |
|---------------------------------------|-------------------|--------------------------------------------------|
| File picker (Ctrl+O)                  | ✓ works           | `xdg-desktop-portal-gtk`, auto-floats            |
| Save-as dialog (Ctrl+S)               | ✓ works           | Same — portal floats by default                  |
| kitty link → firefox focus            | ✗ intermittent    | Addressed by niri `open-focused` rule below      |
| **Firefox OAuth popup spawn**         | ✗ broken          | Addressed in firefox prefs (not niri rule)       |

niri's documented defaults already cover the dialog cases:
- "New windows automatically float if they have a parent."
- "New floating windows open at the center of the screen."

## Why the niri-only approach failed

The first attempt was a title-matched window-rule:

```kdl
window-rule {
    match app-id=r#"firefox$"# title=r#"(?i)(google accounts|...)"#
    open-floating true
}
```

This **does not work** because firefox maps the popup window with the
placeholder title `"Mozilla Firefox"`, and only updates it to
`"Sign In - Google Accounts — Mozilla Firefox"` after the page loads.
`open-floating` is a spawn-time rule, evaluated against the initial title.
The provider name arrives too late.

niri offers no continuous "force to floating" rule property — `is-floating=true`
exists as a *matcher* but cannot be *set* by a rule; floating state is only
changed via actions (`move-window-to-floating`, `toggle-window-floating`).

The remaining niri-only path would be an external watcher daemon subscribed to
`niri msg --json event-stream`, matching firefox windows by title and calling
the action. That was rejected as too many moving parts for one rule.

## Solution

Two changes in two layers.

### Layer 1 — niri config (`niri/.config/niri/config.kdl`)

```kdl
// Firefox windows always claim focus when they open — covers xdg-open from
// another app (kitty link click) where the spawn should immediately surface.
window-rule {
    match app-id=r#"firefox$"#
    open-focused true
}
```

Slotted next to the existing Firefox PiP rule (around line 357). A comment in
the config also notes that the OAuth-popup case lives in firefox prefs and
explains why niri-side matching could not solve it.

### Layer 2 — firefox prefs (`firefox/user.js`, `firefox/install.sh`)

```js
user_pref("browser.link.open_newwindow.restriction", 0);
user_pref("browser.link.open_newwindow", 3);
```

- `restriction=0` makes firefox apply the `open_newwindow` rule even when
  `window.open` passes feature parameters.
- `open_newwindow=3` is "new tab" (already firefox default; listed for clarity).

Together: every `window.open(...)` call becomes a new tab. OAuth flows
(Google, GitHub, Microsoft, …) continue to work as tabs.

Why a script and not stow: firefox profiles live in
`~/.config/mozilla/firefox/<random-hash>.default-release/`. The hash differs
per machine, so a fixed symlink target is impossible. `install.sh` finds the
profile and copies `user.js` into it. Same precedent as
`sysctl/install.sh`, `nftables/install.sh`, `tlp/install.sh`.

## Trade-offs

1. **All `window.open(...)` becomes a tab, not just OAuth.** Includes
   intentional popups (some webapps' "expand to new window" features). The
   user can still manually open a new window with Ctrl+N or `target=_blank`
   tab-style. Accepted.
2. **`open-focused` is unconditional.** All firefox window opens grab focus,
   including manual launches from the launcher. Considered desirable.
3. **firefox restart required** for `user.js` to take effect. One-time cost.

## Out of scope

- Title-matched niri window-rules for firefox popups — proven not viable
  (see above).
- Watcher-daemon implementation — deferred unless the firefox-pref approach
  proves insufficient.
- File-picker / save-dialog rules — already works via portal.

## Done criteria

- Trigger a Google OAuth flow ("Sign in with Google"). The login UI appears
  as a tab in the main firefox window, not as a separate half-tiled window.
- With firefox running on a different workspace from the active kitty,
  `firefox https://example.com` from kitty switches focus to firefox's
  workspace and the firefox window receives keyboard focus.
- File picker and Save-As dialog behavior unchanged.
- `todos.txt` #3 updated.
- Change merged to `laniakea` from `niri-popup-float` feature branch.

## Files touched

- `niri/.config/niri/config.kdl` — added `open-focused` rule + explanatory
  comment about why the popup case lives in firefox prefs
- `firefox/user.js` — new file
- `firefox/install.sh` — new file (finds profile, copies user.js)
- `todos.txt` — narrow item #3 to reflect implemented solution
- `docs/superpowers/specs/2026-05-20-niri-window-spawn-rules-design.md` — this file
