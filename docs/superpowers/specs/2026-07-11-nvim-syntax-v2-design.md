# Sky Paper — nvim Syntax Palette v2

**Date:** 2026-07-11
**Status:** approved (variant B chosen via visual A/B proof)
**Scope:** Neovim syntax + diagnostics only. Kitty ANSI, tmux, Quickshell, niri — untouched.
**Preview artifact:** https://claude.ai/code/artifact/5d8d2f80-dee9-4e5e-b2a0-5e196476ca56

## Problem

The current nvim scheme maps the whole syntax space onto three hues (deep sky, brighter
sky, warm clay) plus fg/muted. Keywords vs functions are near-identical, strings equal
numbers, and types/constants/properties are all plain fg. Diagnostics are monochrome
(errors render sky blue, warnings share the comment gray). Result: flat, low-information
highlighting.

Additionally, **PALETTE.md's contrast ratios were computed against pure white instead of
the cream bg `#F0EBE0`**. Measured correctly, every non-fg color fails WCAG 4.5:1:
deep sky 4.47, bright sky 3.34, clay 3.94, muted 4.02.

## Design decisions

1. **Richer full palette (variant B):** keywords go plum, functions take deep sky.
   Rationale: a "brighter sibling sky" for functions mathematically cannot reach 4.5:1 on
   cream while looking brighter than keyword-sky, so the old sibling-hue trick is retired.
   Variant B maximizes hue distance between the two most frequent token classes.
2. **Anchors retuned, not replaced:** sky, clay, and muted keep their hue and character
   but are darkened until they pass 4.5:1 on `#F0EBE0`.
3. **Semantic diagnostics return:** brick errors, ochre warnings, moss git-adds.
4. **Family constraint:** every hue has saturation ≤ 50% and lightness 28–45% — muted,
   warm-leaning, painterly. No neon on paper.
5. **UI chrome unchanged:** statusline, floats, borders, visual selection, search, and the
   Base palette in PALETTE.md (accent-soft `#A8C0D5`, accent-text `#4A6F8E` for UI use)
   stay as they are. The retuned/added hues are nvim-syntax-scoped.

## Palette (all ratios vs `#F0EBE0`, WCAG)

| hue | hex | ratio | roles |
|---|---|---|---|
| fg | `#1F1812` | 14.75 | variables, properties, parameters, operators |
| muted | `#6E665F` | 4.74 | comments (italic), hints — nvim-only darkening of `#7A716A` |
| plum | `#7A5A8A` | 4.83 | keywords, conditionals, loops |
| deep sky v2 | `#426483` | 5.22 | functions, methods, builtins; diagnostic info; git changed |
| moss | `#4E7040` | 4.75 | types, classes, structs (bold); git added |
| warm clay v2 | `#78603F` | 4.99 | strings |
| rust | `#9A5535` | 4.74 | numbers, booleans, constants (constants bold) |
| brick | `#A2453A` | 5.12 | errors (bold); git deleted |
| dry ochre | `#7D5E12` | 5.07 | warnings |

Retired: bright sky `#5C84A4` (3.34:1, unreachable target on cream).

## Implementation shape (Ars writes it)

- All changes land in the `require('vague').setup({ colors = {...}, style = {...} })`
  block in `nvim/.config/nvim/init.lua` (~line 230). The vague.nvim `colors` table already
  exposes: `comment, builtin, func, string, number, property, constant, parameter, error,
  warning, hint, operator, keyword, type, plus, delta`. Map the table above onto those
  keys; `bg/inactiveBg/fg/floatBorder/line/visual/search` keep current values.
- `style` block: keep `types = "bold"`, `error = "bold"`, `comments = "italic"`.
- Possible gaps needing manual `vim.api.nvim_set_hl(0, ...)` after `colorscheme vague`
  (verify with `:Inspect` / `:hi` before adding): constant bold, builtin italic,
  `DiagnosticInfo` if vague doesn't derive it from a colors key.
- **PALETTE.md follow-up:** rewrite the "Syntax (nvim)" and "Diagnostics" sections with
  the table above; fix the doc's contrast figures (and note ratios are measured against
  `#F0EBE0`, not white). Base/UI tables unchanged.
- **CONTEXT.md:** no changes needed (no package/service/system state changes).

## Verification

- Open a Go and a Python buffer; confirm keyword/function/type/string/number/constant are
  six visibly distinct colors; comments are the only italic gray.
- Trigger a real LSP error + warning (typo an identifier, call a deprecated function):
  error squiggle/virtual text brick, warning ochre.
- Modified git-tracked file: gitsigns gutter shows moss add / sky change / brick delete.
- `:Inspect` on a token confirms which highlight group supplies its color.

## Out of scope

Kitty 16-color table (still near-mono — candidate for a future pass now that semantic
hues exist), lualine theme retint, treesitter per-language tweaking.
