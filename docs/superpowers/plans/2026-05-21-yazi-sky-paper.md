# yazi Sky Paper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Theme yazi 26.5.6 in the Sky Paper palette (UI chrome, filenames, code-preview syntax, and Nerd Font icons neutralized to the palette) and enable kitty image + video/PDF previews, shipped as a stow package.

**Architecture:** New stow package `~/dotfiles/yazi/.config/yazi/` deployed via `stow yazi`. A minimal `theme.toml` deep-merges over yazi's built-in `theme-light.toml` preset, overriding only colors. The full `[icon]` glyph table is vendored with every `fg` stripped so each glyph inherits its filename's palette color. A `sky-paper.tmTheme` drives code-preview syntax to mirror nvim. `yazi.toml` carries a few behavior overrides. `install.sh` ensures `ffmpegthumbnailer` + `poppler` for video/PDF thumbnails.

**Tech Stack:** yazi 26.5.6 / `ya` 26.5.6, TOML, TextMate `.tmTheme` (plist XML), GNU stow, kitty graphics protocol. Palette: `PALETTE.md` (Sky Paper). Branch: `yazi-sky-paper` (already created).

**Palette reference (from PALETTE.md):**
| role | hex |
|---|---|
| bg | `#F0EBE0` |
| bg-alt | `#E4DED0` |
| border-dim | `#C5BFB5` |
| muted | `#7A716A` |
| fg | `#1F1812` |
| accent-soft (sky fill) | `#A8C0D5` |
| accent-text (deep sky) | `#4A6F8E` |
| accent-bright | `#5C84A4` |

**Conventions observed:** `docs/` is gitignored — this plan and the spec are NOT committed. Only the package files under `yazi/` get committed. Never commit on `laniakea` (we are on `yazi-sky-paper`). Memory caveats: kitty primary font is Terminess Nerd Font Mono (icons accepted soft); `~/.config/yazi` does not exist yet so `stow yazi` will fold it into a fresh directory symlink — no clobber risk.

---

### Task 1: Scaffold the stow package

**Files:**
- Create: `~/dotfiles/yazi/.config/yazi/` (directory)

- [ ] **Step 1: Confirm branch and create the package directory tree**

Run:
```bash
cd ~/dotfiles
git branch --show-current   # expect: yazi-sky-paper
mkdir -p yazi/.config/yazi
```
Expected: branch is `yazi-sky-paper`; directory created with no error.

- [ ] **Step 2: Verify the deploy target is absent (no clobber)**

Run:
```bash
ls -ld ~/.config/yazi 2>&1
```
Expected: `No such file or directory` — confirms `stow yazi` will create a clean directory symlink later. If it exists, STOP and inspect before proceeding.

---

### Task 2: Write yazi.toml (behavior overrides)

**Files:**
- Create: `~/dotfiles/yazi/.config/yazi/yazi.toml`

Only override what differs from the preset (`linemode`). Everything else inherits yazi defaults. Preview adapter stays auto (kitty graphics auto-detected); `max_width`/`max_height` left at defaults.

- [ ] **Step 1: Write the file**

```toml
#:schema https://yazi-rs.github.io/schemas/yazi.json

# Sky Paper — behavior overrides only; everything else inherits yazi defaults.
# Theming lives in theme.toml; code-preview syntax in sky-paper.tmTheme.

[mgr]
# Show file size as the right-hand line annotation (default is "none").
linemode = "size"

# Preview adapter is left on auto-detection: inside kitty, yazi uses the
# kitty graphics protocol for images automatically. Video/PDF thumbnails
# need ffmpegthumbnailer + poppler (see install.sh).
```

- [ ] **Step 2: Validate TOML parses**

Run:
```bash
python3 -c "import tomllib; tomllib.load(open('$HOME/dotfiles/yazi/.config/yazi/yazi.toml','rb')); print('ok')"
```
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add yazi/.config/yazi/yazi.toml
git commit -m "yazi: behavior overrides (linemode=size)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: Write sky-paper.tmTheme (code-preview syntax)

**Files:**
- Create: `~/dotfiles/yazi/.config/yazi/sky-paper.tmTheme`

A minimal TextMate `.tmTheme` (plist XML) consumed by yazi's syntect code preview. Scopes map to the exact roles PALETTE.md defines for nvim so previewed code matches the editor.

- [ ] **Step 1: Write the file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>name</key>
	<string>Sky Paper</string>
	<key>settings</key>
	<array>
		<!-- Global -->
		<dict>
			<key>settings</key>
			<dict>
				<key>background</key>
				<string>#F0EBE0</string>
				<key>foreground</key>
				<string>#1F1812</string>
				<key>caret</key>
				<string>#4A6F8E</string>
				<key>selection</key>
				<string>#C5BFB5</string>
				<key>lineHighlight</key>
				<string>#E4DED0</string>
			</dict>
		</dict>
		<!-- Comment -->
		<dict>
			<key>scope</key>
			<string>comment, punctuation.definition.comment</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#7A716A</string>
				<key>fontStyle</key>
				<string>italic</string>
			</dict>
		</dict>
		<!-- Keyword / control / storage -->
		<dict>
			<key>scope</key>
			<string>keyword, keyword.control, keyword.operator.logical, storage, storage.type, storage.modifier</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#4A6F8E</string>
			</dict>
		</dict>
		<!-- Type / class -->
		<dict>
			<key>scope</key>
			<string>entity.name.type, entity.name.class, support.type, support.class</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#1F1812</string>
				<key>fontStyle</key>
				<string>bold</string>
			</dict>
		</dict>
		<!-- Function -->
		<dict>
			<key>scope</key>
			<string>entity.name.function, support.function, meta.function-call</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#1F1812</string>
			</dict>
		</dict>
		<!-- String -->
		<dict>
			<key>scope</key>
			<string>string, string.quoted, punctuation.definition.string</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#7A716A</string>
			</dict>
		</dict>
		<!-- Number / boolean / language constant -->
		<dict>
			<key>scope</key>
			<string>constant.numeric, constant.language, constant.language.boolean</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#7A716A</string>
			</dict>
		</dict>
		<!-- Other constants -->
		<dict>
			<key>scope</key>
			<string>constant.other, constant.character</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#1F1812</string>
			</dict>
		</dict>
		<!-- Operator -->
		<dict>
			<key>scope</key>
			<string>keyword.operator, punctuation.separator, punctuation.terminator</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#7A716A</string>
			</dict>
		</dict>
		<!-- Variable / parameter / property -->
		<dict>
			<key>scope</key>
			<string>variable, variable.parameter, variable.other, meta.object-literal.key, support.variable.property</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>#1F1812</string>
			</dict>
		</dict>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Validate the plist XML parses**

Run:
```bash
python3 -c "import plistlib; d=plistlib.load(open('$HOME/dotfiles/yazi/.config/yazi/sky-paper.tmTheme','rb')); print(d['name'], len(d['settings']), 'blocks')"
```
Expected: `Sky Paper 10 blocks`

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add yazi/.config/yazi/sky-paper.tmTheme
git commit -m "yazi: Sky Paper code-preview syntect theme

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Write theme.toml — UI + filetype colors (top portion)

**Files:**
- Create: `~/dotfiles/yazi/.config/yazi/theme.toml`

This deep-merges over the built-in `theme-light.toml` preset. Only color/style overrides — keys match the preset schema verbatim (`[mgr]`, `[tabs]`, `[mode]`, `[status]`, `[which]`, `[confirm]`, `[spot]`, `[notify]`, `[pick]`, `[input]`, `[cmp]`, `[tasks]`, `[help]`, `[filetype]`). The `[icon]` table is appended in Task 5. `syntect_theme` points at the tmTheme from Task 3. Palette has no red/green — markers/counts/progress/notify use sky/dark/muted tones only.

- [ ] **Step 1: Write the file**

```toml
#:schema https://yazi-rs.github.io/schemas/theme.json
# Sky Paper — overrides theme-light.toml preset. Palette: PALETTE.md.
# bg #F0EBE0 / bg-alt #E4DED0 / border #C5BFB5 / muted #7A716A / fg #1F1812
# accent-soft #A8C0D5 (sky fill) / accent-text #4A6F8E (deep sky) / bright #5C84A4
# No red/green in the palette: state colors use sky/dark/muted only.

[mgr]
cwd = { fg = "#4A6F8E" }

# Find
find_keyword  = { fg = "#4A6F8E", bold = true, italic = true, underline = true }
find_position = { fg = "#7A716A", bg = "reset", bold = true, italic = true }

# Symlink
symlink_target = { fg = "#7A716A", italic = true }

# Marker (thin left bars — fg=bg makes a solid block)
marker_copied   = { fg = "#4A6F8E", bg = "#4A6F8E" }
marker_cut      = { fg = "#1F1812", bg = "#1F1812" }
marker_marked   = { fg = "#5C84A4", bg = "#5C84A4" }
marker_selected = { fg = "#A8C0D5", bg = "#A8C0D5" }

# Count badges
count_copied   = { fg = "#F0EBE0", bg = "#4A6F8E" }
count_cut      = { fg = "#F0EBE0", bg = "#1F1812" }
count_selected = { fg = "#1F1812", bg = "#A8C0D5" }

# Border
border_style = { fg = "#C5BFB5" }

# Code preview syntax (Task 3)
syntect_theme = "~/.config/yazi/sky-paper.tmTheme"

[tabs]
active   = { fg = "#1F1812", bg = "#A8C0D5", bold = true }
inactive = { fg = "#7A716A", bg = "#E4DED0" }

[mode]
normal_main = { fg = "#1F1812", bg = "#A8C0D5", bold = true }
normal_alt  = { fg = "#4A6F8E", bg = "#E4DED0" }
select_main = { fg = "#F0EBE0", bg = "#4A6F8E", bold = true }
select_alt  = { fg = "#4A6F8E", bg = "#E4DED0" }
unset_main  = { fg = "#F0EBE0", bg = "#7A716A", bold = true }
unset_alt   = { fg = "#7A716A", bg = "#E4DED0" }

[status]
# Permissions (no red/green/yellow — sky + muted + dark)
perm_sep   = { fg = "#7A716A" }
perm_type  = { fg = "#4A6F8E" }
perm_read  = { fg = "#7A716A" }
perm_write = { fg = "#1F1812" }
perm_exec  = { fg = "#4A6F8E" }
# Progress
progress_label  = { fg = "#1F1812", bold = true }
progress_normal = { fg = "#A8C0D5", bg = "#E4DED0" }
progress_error  = { fg = "#1F1812", bg = "#C5BFB5" }

[which]
mask            = { bg = "#E4DED0" }
cand            = { fg = "#4A6F8E" }
rest            = { fg = "#7A716A" }
desc            = { fg = "#1F1812" }
separator_style = { fg = "#C5BFB5" }

[confirm]
border  = { fg = "#C5BFB5" }
title   = { fg = "#4A6F8E" }
btn_yes = { fg = "#1F1812", bg = "#A8C0D5", bold = true }
btn_no  = { fg = "#7A716A" }

[spot]
border   = { fg = "#C5BFB5" }
title    = { fg = "#4A6F8E" }
tbl_col  = { fg = "#4A6F8E" }
tbl_cell = { fg = "#1F1812", bg = "#A8C0D5" }

[notify]
title_info  = { fg = "#4A6F8E" }
title_warn  = { fg = "#7A716A" }
title_error = { fg = "#1F1812" }

[pick]
border   = { fg = "#C5BFB5" }
active   = { fg = "#4A6F8E", bold = true }
inactive = { fg = "#7A716A" }

[input]
border   = { fg = "#A8C0D5" }
value    = { fg = "#1F1812" }
selected = { bg = "#C5BFB5" }

[cmp]
border   = { fg = "#C5BFB5" }
active   = { fg = "#1F1812", bg = "#A8C0D5" }
inactive = { fg = "#7A716A" }

[tasks]
border  = { fg = "#C5BFB5" }
hovered = { fg = "#4A6F8E", bold = true }

[help]
on      = { fg = "#4A6F8E" }
run     = { fg = "#1F1812" }
hovered = { fg = "#1F1812", bg = "#A8C0D5", bold = true }
footer  = { fg = "#7A716A", bg = "#E4DED0" }

[filetype]
rules = [
	# Image
	{ mime = "image/*", fg = "#7A716A" },
	# Media
	{ mime = "{audio,video}/*", fg = "#7A716A" },
	# Archive
	{ mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "#7A716A" },
	# Document
	{ mime = "application/{pdf,doc,rtf}", fg = "#4A6F8E" },
	# Virtual file system
	{ mime = "vfs/{absent,stale}", fg = "#C5BFB5" },
	# Special file (no red in palette — orphan uses bold dark fg)
	{ url = "*", is = "orphan", fg = "#1F1812", bold = true },
	{ url = "*", is = "exec",   fg = "#1F1812", bold = true },
	# Dummy file
	{ url = "*", is = "dummy",  fg = "#C5BFB5" },
	{ url = "*/", is = "dummy", fg = "#C5BFB5" },
	# Fallback: directories deep sky, files inherit global fg
	{ url = "*/", fg = "#4A6F8E" },
]
```

- [ ] **Step 2: Validate TOML parses (before [icon] is appended)**

Run:
```bash
python3 -c "import tomllib; tomllib.load(open('$HOME/dotfiles/yazi/.config/yazi/theme.toml','rb')); print('ok')"
```
Expected: `ok`

- [ ] **Step 3: Do NOT commit yet** — `theme.toml` is incomplete until Task 5 appends `[icon]`. Commit happens at the end of Task 5.

---

### Task 5: Append the neutralized [icon] table to theme.toml

**Files:**
- Modify: `~/dotfiles/yazi/.config/yazi/theme.toml` (append `[icon]` section)

Vendor yazi's upstream `[icon]` glyph table with every `fg` stripped, so each glyph inherits its filename's palette color (set by `[filetype]` + global fg). This is the "neutralize to palette" decision: directory glyphs render deep sky, executables bold dark, media muted, etc. — following the filename, not a rainbow.

The transform was verified during planning: `sed -E 's/, fg = "[^"]*"//g'` removes the color field from each `{ name/if, text, fg }` entry, leaving the glyph intact.

- [ ] **Step 1: Fetch the upstream preset (network; sandbox must be disabled for this step)**

Run:
```bash
curl -fsSL "https://raw.githubusercontent.com/sxyazi/yazi/main/yazi-config/preset/theme-light.toml" -o /tmp/yz-theme-upstream.toml
grep -n '^\[icon\]' /tmp/yz-theme-upstream.toml
```
Expected: prints a line number for `[icon]` (≈267). If the fetch returns empty, re-run with the sandbox disabled — GitHub raw is required here.

- [ ] **Step 2: Extract `[icon]`→EOF, strip every fg, append to theme.toml**

Run:
```bash
ICON_START=$(grep -n '^\[icon\]' /tmp/yz-theme-upstream.toml | cut -d: -f1)
{ echo ""; echo "# Icons — upstream glyph table, all fg stripped so each glyph"; \
  echo "# inherits its filename's palette color (see [filetype])."; \
  tail -n +"$ICON_START" /tmp/yz-theme-upstream.toml | sed -E 's/, fg = "[^"]*"//g'; \
} >> "$HOME/dotfiles/yazi/.config/yazi/theme.toml"
```
Expected: no output, exit 0.

- [ ] **Step 3: Verify no fg survived in the icon table and glyphs are intact**

Run:
```bash
awk '/^\[icon\]/{f=1} f' "$HOME/dotfiles/yazi/.config/yazi/theme.toml" | grep -c 'fg ='
awk '/^\[icon\]/{f=1} f' "$HOME/dotfiles/yazi/.config/yazi/theme.toml" | grep -c 'text = "'
```
Expected: first line `0` (no colors left in `[icon]`); second line a large count (>1000) confirming glyphs preserved.

- [ ] **Step 4: Validate the full theme.toml parses**

Run:
```bash
python3 -c "import tomllib; d=tomllib.load(open('$HOME/dotfiles/yazi/.config/yazi/theme.toml','rb')); print('ok, icon keys:', list(d['icon'].keys()))"
```
Expected: `ok, icon keys: ['globs', 'dirs', 'files', 'exts', 'conds']`

- [ ] **Step 5: Commit the complete theme.toml**

```bash
cd ~/dotfiles
git add yazi/.config/yazi/theme.toml
git commit -m "yazi: Sky Paper theme.toml (UI + filetype + neutralized icons)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: install.sh + README.md (thumbnail helpers)

**Files:**
- Create: `~/dotfiles/yazi/install.sh`
- Create: `~/dotfiles/yazi/README.md`

Follows the repo's install.sh convention (`tlp/install.sh`, `keyd/install.sh`): `set -euo pipefail`, `pacman -S --needed` (never `--noconfirm`), idempotent, with a revert note. These deps only enable video/PDF *thumbnails*; yazi degrades to file-info preview without them.

- [ ] **Step 1: Write install.sh**

```bash
#!/usr/bin/env bash
# Optional preview helpers for yazi on laniakea.
#
# Why a script and not part of stow: these are pacman packages, not config.
# The yazi config itself is deployed with `stow yazi` (not this script).
#
# What it installs:
#   - ffmpegthumbnailer: video thumbnails in the preview pane
#   - poppler:           PDF page thumbnails (pdftoppm)
# Image previews work without these (kitty graphics, native formats).
#
# Revert: pacman -Rns ffmpegthumbnailer poppler   (if nothing else needs them)
set -euo pipefail

pacman -S --needed ffmpegthumbnailer poppler

echo "Installed. Spot-check:"
echo "  command -v ffmpegthumbnailer pdftoppm"
echo "Then open a video / PDF in yazi — the preview pane should show a thumbnail."
```

- [ ] **Step 2: Make it executable**

Run:
```bash
chmod +x ~/dotfiles/yazi/install.sh
```
Expected: no output.

- [ ] **Step 3: Write README.md**

```markdown
# yazi — Sky Paper

Sky Paper themed yazi (file manager). Stow package.

## Deploy

```bash
cd ~/dotfiles && stow yazi      # symlinks ~/.config/yazi → here
./yazi/install.sh               # optional: video/PDF thumbnail helpers (sudo)
```

## Files

- `theme.toml` — Sky Paper colors over yazi's `theme-light.toml` preset.
  UI chrome, filetype filename colors, and the `[icon]` glyph table with all
  `fg` stripped so each glyph inherits its filename's palette color.
- `sky-paper.tmTheme` — code-preview syntax, mirrors the nvim palette roles.
- `yazi.toml` — behavior overrides (`linemode = "size"`); rest are defaults.

## Notes

- **Icons:** Nerd Font glyphs kept (kitty's font is Terminess Nerd Font Mono).
  They may render soft at bitmap sizes — accepted trade-off.
- **Image preview:** kitty graphics protocol, auto-detected. Native image
  formats need nothing extra.
- **Video / PDF preview:** needs `ffmpegthumbnailer` + `poppler` —
  run `install.sh`. Without them, yazi shows file info instead of a thumbnail.
- **Delete:** stock yazi — `d` trashes (recoverable), `D` deletes permanently.
- **Regenerate the icon table** (if upstream changes): re-run Task 5 of the
  plan — fetch `theme-light.toml`, `sed -E 's/, fg = "[^"]*"//g'` the
  `[icon]`→EOF slice, replace the section in `theme.toml`.
```

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add yazi/install.sh yazi/README.md
git commit -m "yazi: install.sh (thumbnail deps) + README

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: Deploy and verify

**Files:** none (deploy + manual verification)

- [ ] **Step 1: Stow the package**

Run:
```bash
cd ~/dotfiles && stow yazi
ls -ld ~/.config/yazi && readlink ~/.config/yazi
```
Expected: `~/.config/yazi` is a symlink resolving into `../dotfiles/yazi/.config/yazi` (directory-level symlink, since the target didn't pre-exist). Config files visible through it.

- [ ] **Step 2: Confirm yazi loads the config without errors**

Run:
```bash
yazi --debug 2>&1 | head -40
```
Expected: the debug report lists the config files being read from `~/.config/yazi` and reports **no theme/config parse errors**. (`--debug` prints environment + config info and exits; if it instead opens the TUI, press `q`, then visually confirm step 3.)

- [ ] **Step 3: Visual check — open yazi interactively**

Run:
```bash
yazi ~/dotfiles
```
Verify by eye, then quit with `q`:
- Status bar / mode indicator / borders are Sky Paper (cream bg, sky `#A8C0D5` active blocks, dark text) — no leftover blue/red/green from the dark preset.
- Directory names render deep sky `#4A6F8E`; their glyphs match (not the upstream rainbow).
- Hover a source file (e.g. `PALETTE.md` or a `.lua`): the code preview uses Sky Paper syntax (cream bg, deep-sky keywords, muted comments/strings).
- Hover an image (e.g. `~/Pictures/wallpapers/clouds.png`): an inline thumbnail renders via kitty graphics.

- [ ] **Step 4: Verify trash + thumbnails (after install.sh)**

Run `./yazi/install.sh` (sudo) if not already done, then in `yazi`:
- Hover a PDF and a video file → preview pane shows a thumbnail (confirms `poppler` + `ffmpegthumbnailer`).
- Select a throwaway file, press `d` → it moves to trash (recoverable: `gio trash --list` shows it). Press `D` on another → permanent-delete confirm prompt appears.

- [ ] **Step 5: Update todos.txt and CONTEXT.md**

Mark todo #17 done in `todos.txt` and add a yazi entry to the CONTEXT.md tool table / stow-packages list (note: new stow package `yazi`, Sky Paper, icons neutralized, thumbnail deps via install.sh). Then commit:
```bash
cd ~/dotfiles
git add todos.txt CONTEXT.md
git commit -m "yazi: mark todo #17 done; note package in CONTEXT

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 6: Finish the branch**

Use the `superpowers:finishing-a-development-branch` skill to decide merge into `laniakea` vs PR. Per memory: verify it works first, merge only then; never touch `laniakea` directly until verified.

---

## Notes on verification limits

There is no offline `yazi --check` lint; TOML/plist validity is checked with `python3` (`tomllib`/`plistlib`), and theme/preview correctness is confirmed by the interactive launch in Task 7. Icon-color "inheritance from filename" is a yazi behavior (an icon entry with no `fg` adopts the file's style) — confirmed against the preset schema during planning and visually verified in Task 7 Step 3.
