if vim.g.vscode then dofile(vim.fn.stdpath('config') .. '/vscode.lua') return end

-- ===================
-- Vim Cheatsheet (advanced)
-- ===================
-- NAVIGATION
--   { / }         jump paragraph up / down
--   Ctrl+d / Ctrl+u   half-page down / up
--   gd            go to definition (LSP)
--   gr            go to references (LSP)
--   Ctrl+o / Ctrl+i   jump back / forward in jump list
--   gi            jump to last insert location
--   gf            open file path under cursor
--   %             jump to matching bracket
--   *             search word under cursor forward
--   #             search word under cursor backward
--
-- TEXT OBJECTS (after d, c, y, v)
--   i) / a)       inside / around ()
--   i] / a]       inside / around []
--   i" / a"       inside / around ""
--   it / at       inside / around HTML tag
--   ip / ap       inside / around paragraph
--
-- POWER EDITS
--   ciw           change word
--   ci"           change inside quotes
--   ci(           change inside parens
--   da)           delete around parens (including them)
--   .             repeat last edit
--   gUiw / guiw   UPPERCASE / lowercase word
--   + / -         increment / decrement number
--   5+            increment by 5
--
-- SURROUND (nvim-surround)
--   (visual) )    select text, press the delimiter → wraps it: )"]} ' ` all work
--   (visual) (    opening char wraps WITH spaces: ( sel )   vs  ) → (sel)
--   (visual) St   wrap selection in an HTML tag (prompts for tag name)
--   ysiw)         wrap word in ()
--   yss)          wrap entire line in ()
--   cs)]          change () to []
--   ds)           delete surrounding ()
--
-- MACROS
--   qa            record into register a
--   q             stop recording
--   @a            replay macro a
--   5@a           replay 5 times
--
-- VISUAL MODE
--   V             select whole line
--   Ctrl+v        block select (columns)
--   I (in block)  insert on all selected lines
--   A (in block)  append on all selected lines
--
-- MARKS
--   ma            set mark a at cursor
--   'a            jump to mark a
--   ''            jump to last position before jump
--
-- REGISTERS
--   "ayiw         yank word into register a
--   "ap           paste from register a
--   :reg          view all registers
--
-- CUSTOM KEYBINDS  —  full scheme and rationale: docs/keybinds.md
--
--   Two tiers, and the split between them is physical, not stylistic:
--     <leader> = SPACE   actions INSIDE the editor. You're in normal mode,
--                        letters are free, no modifier needed.
--     Alt                crossing a container border. Inside a terminal
--                        letters are text, so a modifier is mandatory.
--
--   ALT (identical here and in VSCode on the work Mac)
--     M-t             terminal: open / focus toggle — works from BOTH sides
--     M-h M-j M-k M-l focus split; crosses into tmux panes at the edge
--     M-H M-J M-K M-L resize
--     M-v / M-s       split right / down   (vim's <C-w>v / <C-w>s)
--     M-q             close split; if it's the last one, dismiss
--                     the tree or terminal instead
--   ...and, handled by tmux itself: M-z zoom, M-1..9 window, M-n/M-p
--     next/prev window, M-Space session picker, M-u scrollback, M-r reload.
--
--   LEADER (grouped so which-key shows them as menus on <Space>)
--     <Space><Space>  find file            <Space>,   switch tab
--     <Space><CR>     new empty tab        <Space>:   command history
--     <Space>/        grep project
--     <Space>w        write                <Space>q   close tab
--     FIND    \f*   \ff \fg \ft \fr \fh \fs \fk
--     GIT     \g*   \gp \gr \gb   preview / reset / blame hunk
--                   \gd \gq       open / close diff view
--                   \gh \gH       file history (current / repo)
--     TABS    \t*   \tt \td \to \tp   list / close / close others / previous
--     CODE    \c*   \cr \ca \cf \cd  rename / action / format / diagnostics
--     ERRORS  \x*   \xx \xw \xq   diagnostics file / workspace / quickfix
--     TREE    \n \e        toggle tree / toggle focus tree<->file
--     TABS    \1..\9 \0    go to tab N / last tab
--     SESSION \s*   \ss \sl \sd   restore (cwd) / restore last / don't save
--     DASH    \d           start screen (:Dash); auto-shows on `nvim` no-args
--     \?            show all keymaps (which-key)
--
--   BARE KEYS (no leader — these are vim conventions and VSCodeVim maps
--   them itself, so they cost zero config on the Mac)
--     gd gr K       definition / references / hover
--     ]d / [d       next / prev diagnostic
--     ]c / [c       next / prev git hunk
--     H / L         previous / next tab
--     s / S         flash: label-jump / treesitter-select (all windows)

-- ===================
-- Mason bin path (for LSP servers)
-- ===================
vim.env.PATH = vim.fn.stdpath('data') .. '/mason/bin:' .. vim.env.PATH

-- ===================
-- Settings
-- ===================
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.smartindent = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wildmode = 'longest,list'
vim.opt.clipboard = 'unnamedplus'
vim.opt.scrolloff = 30           -- cursor stays centered (your 'so=30')
vim.opt.termguicolors = true     -- needed for modern colorschemes

-- Tab-per-file model (see §TABS in the keymap header): a jump to a file that
-- is already open reuses its tab instead of replacing the current window's
-- buffer, and an unopened one gets its own tab. Without this, `gd` into
-- another file, quickfix and diagnostic jumps silently break the model by
-- leaving a file open with no tab of its own.
vim.opt.switchbuf = 'usetab,newtab'

-- What persistence.nvim saves per session (no globals/terminal — avoids
-- restoring stale toggleterm shells and global-var surprises).
vim.opt.sessionoptions = 'buffers,curdir,folds,tabpages,winsize,winpos,localoptions'

-- Layout-independent commands: with Russian (JCUKEN) active, normal/visual/
-- operator-pending mode keys map to their QWERTY positional equivalents,
-- so `я` acts as `z`, `и` as `b`, `р` as `h`, etc. <leader> sequences too.
-- Doesn't affect insert mode or what gets typed into the buffer.
vim.opt.langmap = 'ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz'

-- Diagnostic display (LSP errors)
vim.diagnostic.config({
  virtual_text = {                                  -- right-of-line truncated text, errors only
    severity = { min = vim.diagnostic.severity.ERROR },  -- errors only — warnings/info/hints come via popup or gutter sign
    source = 'if_many',                             -- show LSP source name when multiple LSPs attached
    prefix = '■',
  },
  signs = true,                                     -- gutter sign for every diagnostic
  underline = true,                                 -- underline the offending text
  float = { border = 'single', source = true },    -- single-line border for hover/diagnostic floats
})

-- Auto-open diagnostic float after holding cursor on a line for 5s
vim.opt.updatetime = 1500  -- ms before CursorHold fires
vim.api.nvim_create_autocmd('CursorHold', {
  callback = function()
    vim.diagnostic.open_float(nil, { focus = false })
  end,
})

-- Quit nvim entirely on :q / :wq when nvim-tree is the only thing left
vim.api.nvim_create_autocmd('QuitPre', {
  callback = function()
    local tree_wins = {}
    local wins = vim.api.nvim_list_wins()
    for _, w in ipairs(wins) do
      local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
      if bufname:match('NvimTree_') ~= nil then
        table.insert(tree_wins, w)
      end
    end
    -- If closing this window leaves only nvim-tree windows, close them too
    if #tree_wins == #wins - 1 then
      for _, w in ipairs(tree_wins) do
        vim.api.nvim_win_close(w, true)
      end
    end
  end,
})

-- Format Go on save (gopls: gofmt + organize imports).
-- gopls is already the Go LSP (see mason-lspconfig ensure_installed). On :w we
-- run its source.organizeImports code action (goimports — add missing / drop
-- unused imports) then its formatter (gofmt-equivalent). buf_request_sync +
-- format are synchronous so the write picks up the reformatted buffer. No extra
-- formatter or plugin — gopls does both jobs.
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.go',
  callback = function(args)
    local client = vim.lsp.get_clients({ bufnr = args.buf, name = 'gopls' })[1]
    if not client then return end
    -- goimports: pull edits from the organizeImports code action and apply them.
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { 'source.organizeImports' }, diagnostics = {} }
    local res = vim.lsp.buf_request_sync(args.buf, 'textDocument/codeAction', params, 1000)
    for _, r in pairs(res or {}) do
      for _, action in pairs(r.result or {}) do
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
        end
      end
    end
    -- gofmt
    vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 1000 })
  end,
})

-- Clear search highlight with Esc
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })


-- ===================
-- Keymaps
-- ===================
-- <leader> = Space. Not F19/CapsLock any more: macOS can only turn CapsLock
-- into Control, Option, Command, Escape or Globe — never F19 — so the old
-- leader was unreproducible on the work Mac. Space needs no keyd, no
-- firmware, and works on the MacBook's built-in keyboard.
-- (mapleader must be set before lazy.setup so plugin `keys` specs pick it up.)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Visual-mode paste keeps the yank register: replaced text → black hole,
-- so `yy` → `vip` then `p` doesn't clobber what you copied.
vim.keymap.set('x', 'p', '"_dP', { desc = 'Paste over selection without clobbering register' })

-- Super+C — the Mac's Cmd+C gesture, arriving as Ctrl+Insert. keyd rewrites
-- the Super pair below the compositor (keyd/etc/keyd/default.conf: Ctrl+C
-- there is SIGINT and could not be reused), kitty forwards it on
-- `copy_or_noop` whenever it has no selection of its own, and nvim decodes the
-- xterm sequence natively — verified by feeding \27[2;5~ to a headless nvim.
--
-- Redundant with `y`, which already reaches the system clipboard through
-- clipboard=unnamedplus. Kept anyway: the point of the scheme is that one
-- gesture works in every layer, and nvim is a layer.
--
-- No <S-Insert> counterpart on purpose — it would be dead code. kitty binds
-- Shift+Insert to paste_from_clipboard and consumes it, so nvim never sees the
-- key; the text arrives as a bracketed paste instead, which nvim already
-- handles correctly.
vim.keymap.set('x', '<C-Insert>', '"+y', { desc = 'Copy selection to system clipboard' })

-- Ctrl+A to select all
vim.keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select all' })

-- Increment/decrement numbers (+ and - in normal mode)
vim.keymap.set('n', '+', '<C-a>', { desc = 'Increment number' })
vim.keymap.set('n', '-', '<C-x>', { desc = 'Decrement number' })

-- Tab navigation (same as your old config)
for i = 1, 9 do
  vim.keymap.set('n', '<leader>' .. i, i .. 'gt', { desc = 'Go to tab ' .. i })
end
vim.keymap.set('n', '<leader>0', ':tablast<CR>', { desc = 'Go to last tab' })

-- Save / close, the two highest-frequency single actions.
-- <leader>w is WRITE, not window: the window namespace moved to Alt (below),
-- which frees w for the obvious meaning.
vim.keymap.set('n', '<leader>w', '<cmd>write<CR>', { desc = 'Write file' })
vim.keymap.set('n', '<leader>q', '<cmd>tabclose<CR>', { desc = 'Close tab' })
-- Space Enter = a new empty tab, mirroring Space Space (find file, which now
-- opens into its own tab). Enter is the "make a new one" key here; <M-t> is
-- NOT available for it — that is the terminal toggle.
vim.keymap.set('n', '<leader><CR>', '<cmd>tabnew<CR>', { desc = 'New tab (empty)' })

-- Tab cycling — bare keys, no leader. Works identically under VSCodeVim.
vim.keymap.set('n', '<S-l>', 'gt', { desc = 'Next tab' })
vim.keymap.set('n', '<S-h>', 'gT', { desc = 'Previous tab' })

-- ---------------------------------------------------------------
-- Alt = containers. The same physical binds drive tmux panes here
-- and VSCode editor groups on the work Mac — see docs/keybinds.md.
--
-- Splits and close go through tmux's if-shell check: tmux forwards the key
-- into nvim when nvim owns the pane, so <M-v> splits *nvim* (one process,
-- shared buffer list and yank register) rather than spawning a second shell.
-- Focus is vim-tmux-navigator (plugin spec below) so it crosses the nvim /
-- tmux boundary without you knowing where the boundary is.
-- ---------------------------------------------------------------
vim.keymap.set('n', '<M-v>', '<C-w>v', { desc = 'Split right' })
vim.keymap.set('n', '<M-s>', '<C-w>s', { desc = 'Split down' })
-- <M-q> (close split / dismiss panel) is set in the toggleterm block below:
-- it needs the tree's and terminal's state to decide what to close.

vim.keymap.set('n', '<M-H>', '<C-w><', { desc = 'Resize left' })
vim.keymap.set('n', '<M-J>', '<C-w>-', { desc = 'Resize down' })
vim.keymap.set('n', '<M-K>', '<C-w>+', { desc = 'Resize up' })
vim.keymap.set('n', '<M-L>', '<C-w>>', { desc = 'Resize right' })

-- Disable arrow keys in normal mode (use hjkl)
vim.keymap.set('n', '<Up>', '<Nop>')
vim.keymap.set('n', '<Down>', '<Nop>')
vim.keymap.set('n', '<Left>', '<Nop>')
vim.keymap.set('n', '<Right>', '<Nop>')

-- Quit all commands
vim.api.nvim_create_user_command('Q', 'qa!', {})       -- :Q  = quit all (no save)
vim.api.nvim_create_user_command('WQ', 'wqa', {})      -- :WQ = save all + quit
vim.api.nvim_create_user_command('Wq', 'wqa', {})

-- ===================
-- Plugin Manager (lazy.nvim)
-- ===================
-- Bootstrap: auto-install lazy.nvim if not present
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- ===================
-- Plugins
-- ===================
require('lazy').setup({
  -- Colorscheme
  --
  {
    'vague2k/vague.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('vague').setup({
        transparent = false,
        style = {
          boolean = "none",
          number = "none",
          float = "none",
          error = "bold",
          comments = "italic",
          conditionals = "none",
          functions = "none",
          headings = "bold",
          operators = "none",
          strings = "none",
          variables = "none",
          keywords = "none",
          types = "bold",
        },
        colors = {
          bg = "#100F0F",
          inactiveBg = "#1C1B1A",
          fg = "#CECDC3",
          floatBorder = "#403E3C",
          line = "#1C1B1A",
          comment = "#878580",
          builtin = "#DA702C",
          func = "#DA702C",
          string = "#3AA99F",
          number = "#8B7EC8",
          property = "#CECDC3",
          constant = "#8B7EC8",
          parameter = "#CECDC3",
          visual = "#403E3C",
          error = "#D14D41",
          warning = "#D0A215",
          hint = "#878580",
          operator = "#CECDC3",
          keyword = "#879A39",
          type = "#D0A215",
          search = "#31234E",
          plus = "#879A39",
          delta = "#878580",
        },
      })
      vim.cmd('colorscheme vague')
    end
  },

  -- Syntax engine: native treesitter (nvim 0.12 ships the runtime + highlighter).
  -- nvim-treesitter is on `main` and used ONLY to install/update parsers; the old
  -- `master` was archived Apr 2026 and won't load on 0.12. Highlighting is nvim-
  -- native via vim.treesitter.start — THIS is what actually engages the structural
  -- syntax palette (@keyword/@function/@string…), see PALETTE.md. Without it the
  -- vague @-groups never apply and you're on legacy regex highlighting.
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter').install({
        'c', 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline',
        'python', 'go', 'gomod', 'bash', 'yaml', 'json', 'toml',
        'dockerfile', 'sql', 'gitcommit', 'diff',
      })
      -- Start the native highlighter for any buffer whose parser is installed.
      -- pcall: silently no-ops for filetypes without a parser (or before an
      -- async install finishes on first launch — works on next open).
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- File explorer
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },  -- file icons
    config = function()
      require('nvim-tree').setup({
        filters = {
          dotfiles = false,
          custom = { 'node_modules', '__pycache__' },  -- same as your old config
        },
        view = {
          width = 30,
        },
        -- Open the tree already scrolled to the file you are editing, with
        -- its parent directories expanded, instead of at the project root.
        -- It re-follows on every buffer switch, so the tree always shows
        -- where you actually are.
        --   update_root = false: expand toward the file but never move the
        --   tree's root, so the project stays the frame of reference.
        update_focused_file = {
          enable = true,
          update_root = false,
        },
        on_attach = function(bufnr)
          local api = require('nvim-tree.api')
          -- Load default mappings first
          api.config.mappings.default_on_attach(bufnr)

          local opts = { buffer = bufnr, noremap = true, silent = true }

          -- Enter opens in new tab (stay in tree)
          vim.keymap.set('n', '<CR>', function()
            api.node.open.tab()
            vim.cmd('tabprev')  -- go back to tree's tab
          end, opts)
          -- o opens in same tab (replace current buffer)
          vim.keymap.set('n', 'o', api.node.open.edit, opts)
          -- Splits
          -- Alt+v / Alt+s, matching the global split vocabulary (was Ctrl+v/h)
          vim.keymap.set('n', '<M-v>', api.node.open.vertical, opts)
          vim.keymap.set('n', '<M-s>', api.node.open.horizontal, opts)

          -- Vim-like navigation (like yazi)
          vim.keymap.set('n', 'l', api.node.open.edit, opts)        -- enter dir / open file
          vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts)  -- close dir / go up

          -- Change tree root
          vim.keymap.set('n', 'H', api.tree.change_root_to_parent, opts)  -- root up
          vim.keymap.set('n', 'L', api.tree.change_root_to_node, opts)    -- root into dir

          -- File ops in vim's own vocabulary, not nvim-tree's defaults.
          -- Upstream puts copy-the-file on `c` and copy-the-NAME on `y`,
          -- which inverts what every other yank in vim means. Here y is the
          -- yank, x the cut, p the paste — the same three letters as in a
          -- buffer, and the same three the VSCode explorer now uses
          -- (docs/vscode/keybindings.json). x and p already match upstream.
          vim.keymap.set('n', 'y', api.fs.copy.node, opts)
          -- v marks a node for a multi-file operation. Upstream has this on
          -- `m` (bookmark); v is what selects in vim, and VSCode's explorer
          -- has no bookmark concept at all — only a selection.
          vim.keymap.set('n', 'v', api.marks.toggle, opts)

          -- Disable arrow keys in tree
          vim.keymap.set('n', '<Up>', '<Nop>', opts)
          vim.keymap.set('n', '<Down>', '<Nop>', opts)
          vim.keymap.set('n', '<Left>', '<Nop>', opts)
          vim.keymap.set('n', '<Right>', '<Nop>', opts)
        end,
      })
    end,
    keys = {
      { '<leader>n', '<cmd>NvimTreeToggle<CR>', desc = 'Toggle file tree' },
      { '<leader>e', function()
          local api = require('nvim-tree.api')
          if vim.bo.filetype == 'NvimTree' then
            vim.cmd('wincmd p')  -- go to previous window
          else
            api.tree.focus()    -- focus tree
          end
        end, desc = 'Toggle focus tree/file' },
    },
  },

  -- Fuzzy finder (fzf-lua — drives the native fzf binary in a separate process,
  -- async; snappier than telescope on big trees, and reuses the fzf already in
  -- $PATH).
  {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local fzf = require('fzf-lua')
      fzf.setup({
        winopts = { border = 'single' },   -- squared corners (Flexoki invariant, no rounded)
        -- Tab / Shift-Tab move the selection, matching blink.cmp's completion
        -- menu so one pair of keys walks every list in the editor. NOTE the
        -- syntax split: the `fzf` table takes fzf's own lowercase-and-dashes
        -- names, the `builtin` table takes vim's `<S-Tab>` form.
        keymap = {
          fzf = {
            ['tab']       = 'down',
            ['shift-tab'] = 'up',
          },
        },
        actions = {
          files = {
            -- Enter opens the file in its OWN TAB. Tabs are vim's window
            -- layouts, not files — but binding one file per tab is what makes
            -- the tabline a visible list of open files, which the buffer list
            -- can never be. See §TABS in the keymap header and
            -- docs/keybinds.md §1.
            ['enter']  = fzf.actions.file_tabedit,
            ['alt-v']  = fzf.actions.file_vsplit,    -- same split vocabulary
            ['alt-s']  = fzf.actions.file_split,     -- as everywhere else
            ['alt-e']  = fzf.actions.file_edit,      -- override: reuse this window
          },
        },
      })
    end,
    keys = {
      -- Top-level shortcuts for the three highest-frequency lookups. Space
      -- Space is the cheapest sequence on the board and goes to the single
      -- most common editor action; <leader>f* below keeps the full menu.
      { '<leader><leader>', '<cmd>FzfLua files<CR>', desc = 'Find file (cwd)' },
      { '<leader>,',        '<cmd>FzfLua tabs<CR>', desc = 'Switch tab' },
      { '<leader>/',        '<cmd>FzfLua live_grep<CR>', desc = 'Grep in project' },
      { '<leader>:',        '<cmd>FzfLua command_history<CR>', desc = 'Command history' },

      { '<leader>ff', function()
          require('fzf-lua').files({
            cmd = 'fd --type f --hidden --exclude .git --exclude .cache . /home /etc /mnt',
            cwd = '/',   -- results span 3 roots (absolute paths from fd); anchor
                         -- display at / so they read home/… etc/… mnt/… instead
                         -- of ../../ relative-to-cwd garbage. Open still resolves right.
          })
        end, desc = 'Find files in /home /etc /mnt' },
      { '<leader>fg', '<cmd>FzfLua live_grep<CR>', desc = 'Grep in project' },
      { '<leader>ft', '<cmd>FzfLua tabs<CR>', desc = 'Open tabs' },
      { '<leader>fr', '<cmd>FzfLua oldfiles<CR>', desc = 'Recent files' },
      { '<leader>fh', '<cmd>FzfLua help_tags<CR>', desc = 'Search help' },
      { '<leader>fs', '<cmd>FzfLua lsp_document_symbols<CR>', desc = 'Symbols in file' },
      { '<leader>fk', '<cmd>FzfLua keymaps<CR>', desc = 'All keymaps' },

      -- Tabs (group <leader>t*) — one tab per file, so this is the "open
      -- files" menu. It was <leader>b* for buffers; the b namespace went away
      -- with the buffer-based workflow rather than being left as a misnomer.
      { '<leader>tt', '<cmd>FzfLua tabs<CR>', desc = 'Tabs: list' },
      { '<leader>td', '<cmd>tabclose<CR>', desc = 'Tabs: close this one' },
      { '<leader>to', '<cmd>tabonly<CR>', desc = 'Tabs: close all others' },
      { '<leader>tp', 'g<Tab>', desc = 'Tabs: previous' },

      -- Diagnostics list (group <leader>x*)
      { '<leader>xx', '<cmd>FzfLua diagnostics_document<CR>', desc = 'Diagnostics: this file' },
      { '<leader>xw', '<cmd>FzfLua diagnostics_workspace<CR>', desc = 'Diagnostics: workspace' },
      { '<leader>xq', '<cmd>FzfLua quickfix<CR>', desc = 'Quickfix list' },
    },
  },

  -- (tabs are rendered by a native numbered tabline — see end of file. No
  -- bufferline plugin: a ~20-line vim.o.tabline does the same numbered tabs
  -- without devicons/powerline slants, which suits the bitmap-native look.)

  -- Git signs in gutter
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      local gitsigns = require('gitsigns')
      gitsigns.setup({
        signs = {
          add          = { text = '+' },
          change       = { text = '~' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
        },
        on_attach = function(bufnr)
          local opts = { buffer = bufnr }

          -- Navigation between hunks
          vim.keymap.set('n', ']c', gitsigns.next_hunk, opts)
          vim.keymap.set('n', '[c', gitsigns.prev_hunk, opts)

          -- Actions (git group: <leader>g*)
          vim.keymap.set('n', '<leader>gp', gitsigns.preview_hunk, { buffer = bufnr, desc = 'Git: preview hunk' })
          vim.keymap.set('n', '<leader>gr', gitsigns.reset_hunk, { buffer = bufnr, desc = 'Git: reset hunk' })
          vim.keymap.set('n', '<leader>gb', gitsigns.blame_line, { buffer = bufnr, desc = 'Git: blame line' })
        end,
      })
    end,
  },

  -- Git diff viewer (side-by-side diffs, file history)
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    -- `keys` alone would leave :DiffviewOpen undefined until one of them is
    -- pressed, so the command form (the only one that takes a revision, e.g.
    -- `:DiffviewOpen origin/celestia -- %`) failed with E492 on a fresh start.
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles', 'DiffviewFocusFiles' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<CR>', desc = 'Open diff view' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<CR>', desc = 'File history (current)' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<CR>', desc = 'File history (repo)' },
      { '<leader>gq', '<cmd>DiffviewClose<CR>', desc = 'Close diff view' },
    },
    opts = {},
  },

  -- Statusline
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      -- Flexoki Dark — see ~/dotfiles/PALETTE.md
      local flexoki_dark = {
        normal = {
          a = { bg = '#8B7EC8', fg = '#100F0F', gui = 'bold' },
          b = { bg = '#343331', fg = '#CECDC3' },
          c = { bg = '#1C1B1A', fg = '#878580' },
        },
        insert = {
          a = { bg = '#CECDC3', fg = '#100F0F', gui = 'bold' },
          b = { bg = '#343331', fg = '#CECDC3' },
          c = { bg = '#1C1B1A', fg = '#878580' },
        },
        visual = {
          a = { bg = '#878580', fg = '#100F0F', gui = 'bold' },
          b = { bg = '#343331', fg = '#CECDC3' },
          c = { bg = '#1C1B1A', fg = '#878580' },
        },
        replace = {
          a = { bg = '#D14D41', fg = '#100F0F', gui = 'bold' },
          b = { bg = '#343331', fg = '#CECDC3' },
          c = { bg = '#1C1B1A', fg = '#878580' },
        },
        command = {
          a = { bg = '#A699D0', fg = '#100F0F', gui = 'bold' },
          b = { bg = '#343331', fg = '#CECDC3' },
          c = { bg = '#1C1B1A', fg = '#878580' },
        },
        inactive = {
          a = { bg = '#1C1B1A', fg = '#878580' },
          b = { bg = '#1C1B1A', fg = '#878580' },
          c = { bg = '#1C1B1A', fg = '#878580' },
        },
      }
      require('lualine').setup({
        options = {
          theme = flexoki_dark,
          section_separators = '',
          component_separators = '|',
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff' },
          lualine_c = { 'filename' },
          lualine_x = { 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
      })
    end,
  },


  -- LSP installer
  {
    'williamboman/mason.nvim',
    lazy = false,
    config = function()
      require('mason').setup()
    end,
  },

  -- Autopairs (Rust-powered, replaces nvim-autopairs)
  {
    'saghen/blink.pairs',
    version = '*',
    dependencies = { 'saghen/blink.download' },
    -- v0.6+ needs the native lib fetched explicitly; download() grabs a
    -- prebuilt binary (no Rust toolchain needed), pwait blocks up to 60s.
    build = function() require('blink.pairs').download():pwait(60000) end,
    opts = {
      mappings = { enabled = true },
      highlights = { enabled = true },
    },
  },

  -- LSP config
  {
    'neovim/nvim-lspconfig',
    lazy = false,
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Keybinds on LSP attach
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          local opts = { buffer = args.buf }
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          -- Group <leader>c* (code), not l* (lsp): "lsp" is plumbing, "code"
          -- is what you're actually doing, and it matches the VSCode side.
          vim.keymap.set('n', '<leader>cr', vim.lsp.buf.rename, { buffer = args.buf, desc = 'Code: rename symbol' })
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code: code action' })
          vim.keymap.set('n', '<leader>cf', function() vim.lsp.buf.format({ async = true }) end,
            { buffer = args.buf, desc = 'Code: format buffer' })
          vim.keymap.set('n', '<leader>cd', vim.diagnostic.open_float, { buffer = args.buf, desc = 'Code: line diagnostics' })
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)

          -- Built-in signature help (replaces lsp_signature.nvim).
          -- Guarded: not every server advertises signatureHelpProvider
          -- (yamlls, dockerls, bashls don't), and LspAttach fires per client.
          if client and client:supports_method('textDocument/signatureHelp') then
            vim.api.nvim_create_autocmd('CursorHoldI', {
              buffer = args.buf,
              callback = vim.lsp.buf.signature_help,
            })
          end
        end,
      })

      -- mason-lspconfig auto-setup
      require('mason-lspconfig').setup({
        ensure_installed = { 'clangd', 'pyright', 'bashls', 'yamlls', 'dockerls', 'docker_compose_language_service', 'lua_ls', 'gopls', 'sqls' },
        handlers = {
          -- Default handler for all servers
          function(server_name)
            lspconfig[server_name].setup({
              capabilities = capabilities,
            })
          end,
          -- Custom setup for yamlls
          ['yamlls'] = function()
            lspconfig.yamlls.setup({
              capabilities = capabilities,
              settings = {
                yaml = {
                  schemas = {
                    kubernetes = 'k8s/**/*.yaml',
                  },
                },
              },
            })
          end,
        },
      })
    end,
  },

  -- Completion engine (Rust-powered, replaces nvim-cmp + 5 source plugins)
  {
    'saghen/blink.cmp',
    version = '*',
    lazy = false,
    dependencies = { 'saghen/blink.download' },
    opts = {
      keymap = {
        preset = 'default',
        ['<CR>'] = { 'accept', 'fallback' },
        ['<Tab>'] = { 'select_next', 'fallback' },
        ['<S-Tab>'] = { 'select_prev', 'fallback' },
      },
      sources = {
        default = { 'lsp', 'snippets', 'buffer', 'path' },
      },
      completion = {
        documentation = { auto_show = true },
      },
    },
  },
  -- Dropdown terminal:
  --   CapsLock t    open the terminal, or toggle focus between it and the
  --                 editor if it's already showing (never hides it)
  --   CapsLock q    universal "dismiss panel" (smart_close, defined below):
  --                 closes tree/terminal but never the code window
  -- One keypress moves focus across nvim splits AND tmux panes: at the edge
  -- of nvim the key is handed back to tmux, which selects the next pane.
  -- Default mappings are off — the scheme uses Alt, not Ctrl, because
  -- Ctrl+h/j/k/l would eat Backspace (0x08), newline (0x0A), fish's kill-line
  -- and clear-screen in the shell. See docs/keybinds.md.
  {
    'christoomey/vim-tmux-navigator',
    init = function()
      vim.g.tmux_navigator_no_mappings = 1
    end,
    cmd = {
      'TmuxNavigateLeft', 'TmuxNavigateDown',
      'TmuxNavigateUp', 'TmuxNavigateRight',
    },
    keys = {
      { '<M-h>', '<cmd>TmuxNavigateLeft<CR>',  desc = 'Focus left'  },
      { '<M-j>', '<cmd>TmuxNavigateDown<CR>',  desc = 'Focus down'  },
      { '<M-k>', '<cmd>TmuxNavigateUp<CR>',    desc = 'Focus up'    },
      { '<M-l>', '<cmd>TmuxNavigateRight<CR>', desc = 'Focus right' },
    },
  },

  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup({
        direction = 'horizontal',
        size = 15,
        shade_terminals = false,
      })

      local function kill()
        for _, t in ipairs(require('toggleterm.terminal').get_all(true)) do
          t:shutdown()
        end
      end

      -- Alt+t: open the terminal if it isn't showing in this tab,
      -- otherwise just bounce focus between the terminal and the editor
      -- (never hides it — the shell stays visible and alive).
      local function smart_toggle()
        local t = require('toggleterm.terminal').get_all(true)[1]
        if t and t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) then
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(w) == t.bufnr then
              if w == vim.api.nvim_get_current_win() then
                vim.cmd('wincmd p')            -- in terminal -> back to editor
              else
                vim.api.nvim_set_current_win(w) -- in editor -> into terminal
              end
              return
            end
          end
        end
        if t then t:open() else vim.cmd('ToggleTerm') end  -- not visible here -> open
      end

      -- Alt+q : universal close. One rule — "get rid of the thing I mean" —
      -- and the code window is NEVER the thing, so this can be mashed safely.
      --   1. cursor inside the terminal    -> kill the terminal
      --   2. cursor inside nvim-tree       -> close the tree
      --   3. cursor in a code window, and there is more than one code
      --      window                        -> close this split
      --   4. cursor in the LAST code window (closing it would empty nvim):
      --        tree open anywhere          -> close the tree
      --        terminal open anywhere      -> kill the terminal
      --        nothing open                -> do nothing
      --
      -- Step 4 is the case that matters day to day: tree open on the left,
      -- cursor in the file you are editing, Alt+q dismisses the tree without
      -- making you jump into it first.
      local function code_window_count()
        local n = 0
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local b = vim.api.nvim_win_get_buf(w)
          local ft = vim.api.nvim_get_option_value('filetype', { buf = b })
          local bt = vim.api.nvim_get_option_value('buftype', { buf = b })
          if ft ~= 'NvimTree' and bt ~= 'terminal' then n = n + 1 end
        end
        return n
      end

      local function smart_close()
        local tree = require('nvim-tree.api').tree
        if vim.bo.buftype == 'terminal' then kill(); return end         -- 1
        if vim.bo.filetype == 'NvimTree' then tree.close(); return end  -- 2
        if code_window_count() > 1 then vim.cmd('close'); return end    -- 3
        if tree.is_visible() then tree.close(); return end              -- 4a
        local t = require('toggleterm.terminal').get_all(true)[1]
        if t and t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) then kill() end  -- 4b
      end

      -- Alt+t is THE central bind of the whole scheme: it has to work from
      -- both sides of the editor/terminal border. Inside the terminal a bare
      -- <leader> sequence is impossible — Space and the letter would just be
      -- typed into the shell — so the border crossing needs a modifier.
      -- Same key toggles the VSCode terminal panel on the work Mac.
      --
      -- tmux deliberately leaves M-t unbound so it reaches nvim here.
      vim.keymap.set('n', '<M-t>', smart_toggle, { desc = 'Terminal: open / focus toggle' })
      vim.keymap.set('t', '<M-t>', smart_toggle, { desc = 'Terminal: open / focus toggle' })
      -- Alt+q lives here rather than next to the other Alt binds because it
      -- needs toggleterm's and nvim-tree's state to decide what to close.
      vim.keymap.set('n', '<M-q>', smart_close, { desc = 'Close split / dismiss panel' })
      vim.keymap.set('t', '<M-q>', smart_close, { desc = 'Close terminal panel' })
    end,
  },

  {
    'kylechui/nvim-surround',
    event = 'VeryLazy',
    config = function()
      require('nvim-surround').setup({})

      -- In visual mode, press the delimiter itself to wrap the selection — no
      -- need to press S first. Select text, hit ) " ' ] } etc. → bam, surrounded.
      -- Closing char is tight: )"]} → (sel) "sel" [sel] {sel}
      -- Opening char keeps spaces: ([{  → ( sel ) [ sel ] { sel }
      -- We bind to <Plug>(nvim-surround-visual); its getchar() then consumes the
      -- trailing delimiter raw, so text objects (vi(, va", ci[…) are untouched.
      -- < and > are left alone on purpose — they're visual indent in/out.
      --
      -- On a LINEWISE selection (V) nvim-surround deliberately puts each
      -- delimiter on its own line, turning one line into three:
      --     (
      --     line
      --     )
      -- Wanted here is the inline form, (line), so a V selection is redrawn
      -- as a charwise one covering the same text before the wrap runs.
      --
      -- Simply pressing v does NOT work: in V mode both visual ends sit at
      -- column 0, so switching to charwise yields a one-character selection
      -- and you get (h)ello. The range has to be rebuilt from the '< and '>
      -- marks, which is also the only way that survives selecting upwards —
      -- there the active end is the FIRST line, not the last.
      -- NOT an expr mapping: expr runs under textlock, where changing the
      -- buffer or the mode is forbidden, so the reselect below silently does
      -- nothing and the wrap never happens.
      local function t(keys)
        return vim.api.nvim_replace_termcodes(keys, true, false, true)
      end

      local function surround_visual(ch)
        return function()
          if vim.fn.mode() == 'V' then
            -- <Esc> commits '< and '>; the x flag runs it before we read them.
            vim.api.nvim_feedkeys(t('<Esc>'), 'nx', false)
            local sl = vim.api.nvim_buf_get_mark(0, '<')[1]
            local el = vim.api.nvim_buf_get_mark(0, '>')[1]
            local width = math.max(#vim.fn.getline(el), 1)
            vim.cmd(('normal! %dG0v%dG%d|'):format(sl, el, width))
          end
          -- 'm' so <Plug> is resolved through the mapping table.
          vim.api.nvim_feedkeys(t('<Plug>(nvim-surround-visual)' .. ch), 'm', false)
        end
      end

      for _, ch in ipairs({ '(', ')', '[', ']', '{', '}', '"', "'", '`' }) do
        vim.keymap.set('x', ch, surround_visual(ch),
          { desc = 'Surround selection with ' .. ch })
      end
    end,
  },

  -- Session persistence, keyed per cwd. Restore is MANUAL (\ss) on purpose:
  -- opening `nvim somefile` shouldn't yank in a whole restored session. Pairs
  -- with tmux-continuum (that restores the terminal layout; this restores the
  -- nvim-internal state — open buffers, tabs, window sizes, folds).
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
    keys = {
      { '<leader>ss', function() require('persistence').load() end, desc = 'Session: restore (cwd)' },
      { '<leader>sl', function() require('persistence').load({ last = true }) end, desc = 'Session: restore last' },
      { '<leader>sd', function() require('persistence').stop() end, desc = "Session: don't save this one" },
    },
  },

  -- Label-based motion: `s` jumps to any spot across ALL visible windows, `S`
  -- selects by treesitter node (needs the parsers above). `S` is left off
  -- visual mode so nvim-surround's visual `S` still wraps.
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash jump' },
      { 'S', mode = { 'n', 'o' }, function() require('flash').treesitter() end, desc = 'Flash treesitter select' },
    },
  },

  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      {
        '<leader>?',
        function()
          require('which-key').show({ global = true })
        end,
        desc = 'All keymaps (which-key)',
      },
    },
  },
})

-- ===================
-- Tabline (native, numbered — replaces bufferline)
-- ===================
-- Renders " N:name " per tab, active tab in Flexoki purple. No icons/powerline
-- slants — plain text reads clean in the bitmap font and matches the \1..\9
-- workflow. Highlights are (re)applied on every ColorScheme so vague loading
-- (or a live reload) can't wipe them.
local function set_tabline_hl()
  vim.api.nvim_set_hl(0, 'TabLineSel',  { fg = '#100F0F', bg = '#8B7EC8', bold = true })
  vim.api.nvim_set_hl(0, 'TabLine',     { fg = '#878580', bg = '#1C1B1A' })
  vim.api.nvim_set_hl(0, 'TabLineFill', { bg = '#1C1B1A' })
end
vim.api.nvim_create_autocmd('ColorScheme', { callback = set_tabline_hl })
set_tabline_hl()

function _G.flexoki_tabline()
  local s = ''
  for i = 1, vim.fn.tabpagenr('$') do
    local buflist = vim.fn.tabpagebuflist(i)
    local bufnr = buflist[vim.fn.tabpagewinnr(i)]
    local name = vim.fn.bufname(bufnr)
    name = name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':t')
    local mod = vim.bo[bufnr].modified and ' +' or ''
    local hl = (i == vim.fn.tabpagenr()) and '%#TabLineSel#' or '%#TabLine#'
    s = s .. hl .. '%' .. i .. 'T ' .. i .. ':' .. name .. mod .. ' '
  end
  return s .. '%#TabLineFill#%T'
end

vim.o.tabline = '%!v:lua.flexoki_tabline()'
vim.o.showtabline = 2   -- always show the tabline

-- ===================
-- Start screen / dashboard (custom, no plugin)
-- ===================
-- Shown on `nvim` with no file args. The Braille art lives in dashboard.txt
-- (bitmap-native in Terminus). Sessions come from persistence.nvim: top 5 by
-- recency are pickable by number, `s` opens an fzf-lua picker over all of them.
-- Reopen anytime with \d or :Dash.
do
  local ns = vim.api.nvim_create_namespace('dashboard')
  local art_path = vim.fn.stdpath('config') .. '/dashboard.txt'

  local function dash_hl()
    vim.api.nvim_set_hl(0, 'DashArt',  { fg = '#8B7EC8' })               -- accent
    vim.api.nvim_set_hl(0, 'DashHead', { fg = '#575653' })               -- faint
    vim.api.nvim_set_hl(0, 'DashKey',  { fg = '#8B7EC8', bold = true })  -- accent bold
    vim.api.nvim_set_hl(0, 'DashText', { fg = '#CECDC3' })               -- fg
    vim.api.nvim_set_hl(0, 'DashTime', { fg = '#575653' })               -- faint
    vim.api.nvim_set_hl(0, 'DashSep',  { fg = '#403E3C' })               -- border-dim
  end
  vim.api.nvim_create_autocmd('ColorScheme', { callback = dash_hl })
  dash_hl()

  -- persistence session files -> { {label, file, mtime}, ... } newest first.
  -- persistence encodes cwd as %-joined path, then `%%`, then the git branch.
  local function sessions()
    local ok, p = pcall(require, 'persistence')
    if not ok then return {} end
    local out = {}
    for _, file in ipairs(p.list()) do
      local base = vim.fn.fnamemodify(file, ':t:r')      -- drop dir + .vim
      local cwd_enc, branch = base:match('^(.-)%%%%(.*)$')
      if not cwd_enc then cwd_enc = base end
      local cwd = cwd_enc:gsub('%%', '/')
      local label = vim.fn.fnamemodify(cwd, ':h:t') .. '/' .. vim.fn.fnamemodify(cwd, ':t')
      label = label:gsub('^/', '')
      if branch and branch ~= '' then label = label .. ' :' .. branch:gsub('%%', '/') end
      local st = vim.uv.fs_stat(file)
      out[#out + 1] = { label = label, file = file, mtime = st and st.mtime.sec or 0 }
    end
    table.sort(out, function(a, b) return a.mtime > b.mtime end)
    return out
  end

  local function ago(sec)
    local d = os.time() - sec
    if d < 3600 then return math.max(1, math.floor(d / 60)) .. 'm ago'
    elseif d < 86400 then return math.floor(d / 3600) .. 'h ago'
    else return math.floor(d / 86400) .. 'd ago' end
  end

  local function load_session(file)
    vim.cmd('silent! source ' .. vim.fn.fnameescape(file))
  end

  local function pick_session()
    local ss = sessions()
    if #ss == 0 then vim.notify('no sessions yet', vim.log.levels.INFO); return end
    local items, map = {}, {}
    for _, s in ipairs(ss) do items[#items + 1] = s.label; map[s.label] = s.file end
    require('fzf-lua').fzf_exec(items, {
      prompt = 'sessions> ',
      winopts = { border = 'single' },   -- squared, matches \ff
      actions = { ['default'] = function(sel)
        if sel and sel[1] and map[sel[1]] then load_session(map[sel[1]]) end
      end },
    })
  end

  local function open()
    local width = vim.o.columns
    local lines, marks = {}, {}   -- marks: { row0, startcol, endcol, group }
    local first_sess           -- 1-based index into `lines` of first session row

    local function add(str, group)          -- centered whole-line
      local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(str)) / 2))
      local full = string.rep(' ', pad) .. str
      lines[#lines + 1] = full
      if group and str ~= '' then marks[#marks + 1] = { #lines - 1, pad, #full, group } end
    end

    local function add_session(i, s)
      local key, lbl, tstr = tostring(i), s.label, ago(s.mtime)
      if #lbl > 44 then lbl = lbl:sub(1, 44) end
      local left = key .. '   ' .. lbl
      local cw = 58
      local gap = math.max(1, cw - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(tstr))
      local str = left .. string.rep(' ', gap) .. tstr
      local pad = math.max(0, math.floor((width - cw) / 2))
      lines[#lines + 1] = string.rep(' ', pad) .. str
      local b = pad
      marks[#marks + 1] = { #lines - 1, b, b + #key, 'DashKey' }
      marks[#marks + 1] = { #lines - 1, b + #key + 3, b + #key + 3 + #lbl, 'DashText' }
      marks[#marks + 1] = { #lines - 1, b + #left + gap, b + #str, 'DashTime' }
      if not first_sess then first_sess = #lines end
    end

    local function add_actions(kvs)
      local parts = {}
      for _, kv in ipairs(kvs) do parts[#parts + 1] = kv[1] .. '  ' .. kv[2] end
      local str = table.concat(parts, '     ')
      local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(str)) / 2))
      lines[#lines + 1] = string.rep(' ', pad) .. str
      local col = pad
      for _, kv in ipairs(kvs) do
        marks[#marks + 1] = { #lines - 1, col, col + #kv[1], 'DashKey' }
        marks[#marks + 1] = { #lines - 1, col + #kv[1] + 2, col + #(kv[1] .. '  ' .. kv[2]), 'DashText' }
        col = col + #(kv[1] .. '  ' .. kv[2]) + 5
      end
    end

    -- art — dropped when the window is too short to also fit the sessions and
    -- actions, so the functional part is never pushed off the bottom (16 ≈
    -- host + 5 sessions + separators + action rows + footer).
    local art = vim.fn.filereadable(art_path) == 1 and vim.fn.readfile(art_path) or {}
    if (vim.o.lines - 2) >= #art + 16 then
      for _, a in ipairs(art) do add(a, 'DashArt') end
      add('')
    end
    add('λ  ' .. vim.uv.os_gethostname(), 'DashArt')
    add('')

    local ss = sessions()
    add('──  sessions  ' .. string.rep('─', 18), 'DashSep')
    if #ss == 0 then
      add('(no sessions yet — save one with :wq inside a project)', 'DashHead')
    else
      for i = 1, math.min(5, #ss) do add_session(i, ss[i]) end
    end
    add(string.rep('─', 32), 'DashSep')
    add_actions({ { 's', 'all sessions (fuzzy)' } })
    add_actions({ { 'f', 'find file' }, { 'r', 'recent' }, { 'e', 'tree' }, { 'q', 'quit' } })
    add('')
    local sok, st = pcall(require('lazy').stats)
    if sok then add(string.format('%d plugins · %dms', st.count, math.floor(st.startuptime + 0.5)), 'DashHead') end

    -- vertical centering
    local top = math.max(0, math.floor(((vim.o.lines - 2) - #lines) / 2))
    local final = {}
    for _ = 1, top do final[#final + 1] = '' end
    vim.list_extend(final, lines)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, final)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].filetype = 'dashboard'
    for _, m in ipairs(marks) do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, m[1] + top, m[2], { end_col = m[3], hl_group = m[4] })
    end

    vim.api.nvim_set_current_buf(buf)
    local w = vim.api.nvim_get_current_win()
    -- Window-local dashboard look. Capture prev so we can restore on leave:
    -- opening a file in THIS window would otherwise inherit nonumber, which
    -- then leaks into saved sessions via 'localoptions'. Read prev here (after
    -- set_current_buf above) so a resize re-render's restore has already run.
    local prev_wo = {}
    for opt, val in pairs({ number = false, relativenumber = false, list = false,
                            cursorline = false, wrap = false,
                            signcolumn = 'no', fillchars = 'eob: ' }) do
      prev_wo[opt] = vim.wo[w][opt]
      vim.wo[w][opt] = val
    end
    if first_sess then pcall(vim.api.nvim_win_set_cursor, w, { top + first_sess, 0 }) end

    -- Hide the block cursor while the dashboard is up; restore on leave. (Read
    -- prev AFTER set_current_buf above so a resize re-render, which wipes the
    -- old dashboard buf and fires its restore first, captures the real value.)
    local prev_guicursor = vim.o.guicursor
    -- cursor colour = bg (#100F0F): the block renders bg-on-bg, invisible in the
    -- terminal; blend=100 hides it in a GUI too.
    vim.api.nvim_set_hl(0, 'DashCursor', { fg = '#100F0F', bg = '#100F0F', blend = 100 })
    vim.o.guicursor = 'a:DashCursor'
    vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWipeout' }, {
      buffer = buf, once = true,
      callback = function()
        vim.o.guicursor = prev_guicursor
        if vim.api.nvim_win_is_valid(w) then
          for opt, val in pairs(prev_wo) do vim.wo[w][opt] = val end
        end
      end,
    })

    -- buffer-local keys
    local function map(k, fn) vim.keymap.set('n', k, fn, { buffer = buf, nowait = true, silent = true }) end
    for i = 1, math.min(5, #ss) do map(tostring(i), function() load_session(ss[i].file) end) end
    map('s', pick_session)
    map('f', function() require('fzf-lua').files({
      cmd = 'fd --type f --hidden --exclude .git --exclude .cache . /home /etc /mnt', cwd = '/' }) end)
    map('r', function() require('fzf-lua').oldfiles() end)
    map('e', function() require('nvim-tree.api').tree.toggle() end)
    map('q', function() vim.cmd('qa') end)
  end

  vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
      if vim.fn.argc() ~= 0 then return end                       -- opened with a file/dir
      if vim.api.nvim_buf_line_count(0) > 1 then return end        -- stdin/piped content
      if (vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or '') ~= '' then return end
      if vim.fn.expand('%') ~= '' then return end
      vim.schedule(open)   -- after startup so lazy.stats() is ready
    end,
  })
  vim.api.nvim_create_user_command('Dash', open, { desc = 'Open the start screen' })
  vim.keymap.set('n', '<leader>d', open, { desc = 'Dashboard' })
  vim.api.nvim_create_autocmd('VimResized', {
    callback = function() if vim.bo.filetype == 'dashboard' then open() end end,
  })
end
