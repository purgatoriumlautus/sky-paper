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
-- CUSTOM KEYBINDS
--   \n            toggle file tree
--   \e            toggle focus tree/file
--   \ff / \fg     find files / grep project
--   \fb / \fr     buffers / recent files
--   \gd / \gq     open / close diff view
--   \gh / \gH     file history (current / repo)
--   \hp / \hr / \hb   preview / reset / blame hunk
--   ]c / [c       next / prev git hunk
--   ]d / [d       next / prev diagnostic
--   K             hover docs
--   \rn / \ca     rename / code action
--   \t            toggle terminal
--   \?            show all keymaps

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

-- Clear search highlight with Esc
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })


-- ===================
-- Keymaps
-- ===================
-- Note: <leader> is backslash by default. Change with: vim.g.mapleader = ' '

-- CapsLock is remapped to F19 by keyd (see dotfiles keyd/); use it as <leader>.
-- (F19, not F13: it's the only F-key keyd can emit that the us xkb keymap
-- gives a clean keysym instead of a terminal-dropped XF86* vendor key.)
vim.keymap.set({ 'n', 'x', 'o' }, '<F19>', '<Leader>', { remap = true })

-- Visual-mode paste keeps the yank register: replaced text → black hole,
-- so `yy` → `vip` then `p` doesn't clobber what you copied.
vim.keymap.set('x', 'p', '"_dP', { desc = 'Paste over selection without clobbering register' })

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
          bg = "#F0EBE0",
          inactiveBg = "#E4DED0",
          fg = "#1F1812",
          floatBorder = "#C5BFB5",
          line = "#E4DED0",
          comment = "#7A716A",
          builtin = "#5C84A4",
          func = "#5C84A4",
          string = "#8B6F4E",
          number = "#8B6F4E",
          property = "#1F1812",
          constant = "#1F1812",
          parameter = "#1F1812",
          visual = "#C5BFB5",
          error = "#4A6F8E",
          warning = "#7A716A",
          hint = "#7A716A",
          operator = "#1F1812",
          keyword = "#4A6F8E",
          type = "#1F1812",
          search = "#C5BFB5",
          plus = "#1F1812",
          delta = "#7A716A",
        },
      })
      vim.cmd('colorscheme vague')
    end
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
          vim.keymap.set('n', '<C-v>', api.node.open.vertical, opts)
          vim.keymap.set('n', '<C-h>', api.node.open.horizontal, opts)

          -- Vim-like navigation (like yazi)
          vim.keymap.set('n', 'l', api.node.open.edit, opts)        -- enter dir / open file
          vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts)  -- close dir / go up

          -- Change tree root
          vim.keymap.set('n', 'H', api.tree.change_root_to_parent, opts)  -- root up
          vim.keymap.set('n', 'L', api.tree.change_root_to_node, opts)    -- root into dir

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

  -- Fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local actions = require('telescope.actions')
      require('telescope').setup({
        defaults = {
          mappings = {
            i = {  -- insert mode
              ['<CR>'] = actions.select_tab,      -- Enter opens in new tab
              ['<C-v>'] = actions.select_vertical,  -- Ctrl+v vertical split
              ['<C-h>'] = actions.select_horizontal, -- Ctrl+h horizontal split
            },
            n = {  -- normal mode
              ['<CR>'] = actions.select_tab,
              ['<C-v>'] = actions.select_vertical,
              ['<C-h>'] = actions.select_horizontal,
            },
          },
        },
      })
    end,
    keys = {
      { '<leader>ff', function()
          require('telescope.builtin').find_files({
            find_command = { 'fd', '--type', 'f', '--hidden', '--exclude', '.git', '--exclude', '.cache', '.', '/home', '/etc', '/mnt' },
          })
        end, desc = 'Find files in /home /etc /mnt' },
      { '<leader>fg', '<cmd>Telescope live_grep<CR>', desc = 'Grep in project' },
      { '<leader>fb', '<cmd>Telescope buffers<CR>', desc = 'Open buffers' },
      { '<leader>fr', '<cmd>Telescope oldfiles<CR>', desc = 'Recent files' },
      { '<leader>fh', '<cmd>Telescope help_tags<CR>', desc = 'Search help' },
    },
  },

  -- Better looking tabs
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('bufferline').setup({
        options = {
          mode = 'tabs',              -- show tabs, not buffers
          numbers = 'ordinal',        -- show tab numbers (1, 2, 3...)
          separator_style = 'thick',  -- slant separators
          show_buffer_close_icons = false,
          show_close_icon = false,
        },
      })
    end,
  },

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

          -- Actions
          vim.keymap.set('n', '<leader>hp', gitsigns.preview_hunk, opts)
          vim.keymap.set('n', '<leader>hr', gitsigns.reset_hunk, opts)
          vim.keymap.set('n', '<leader>hb', gitsigns.blame_line, opts)
        end,
      })
    end,
  },

  -- Git diff viewer (side-by-side diffs, file history)
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
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
      -- Sky Paper — see ~/dotfiles/PALETTE.md
      local sky_paper = {
        normal = {
          a = { bg = '#A8C0D5', fg = '#1F1812', gui = 'bold' },
          b = { bg = '#C5BFB5', fg = '#1F1812' },
          c = { bg = '#E4DED0', fg = '#7A716A' },
        },
        insert = {
          a = { bg = '#1F1812', fg = '#F0EBE0', gui = 'bold' },
          b = { bg = '#C5BFB5', fg = '#1F1812' },
          c = { bg = '#E4DED0', fg = '#7A716A' },
        },
        visual = {
          a = { bg = '#7A716A', fg = '#F0EBE0', gui = 'bold' },
          b = { bg = '#C5BFB5', fg = '#1F1812' },
          c = { bg = '#E4DED0', fg = '#7A716A' },
        },
        replace = {
          a = { bg = '#1F1812', fg = '#F0EBE0', gui = 'bold' },
          b = { bg = '#C5BFB5', fg = '#1F1812' },
          c = { bg = '#E4DED0', fg = '#7A716A' },
        },
        command = {
          a = { bg = '#4A6F8E', fg = '#F0EBE0', gui = 'bold' },
          b = { bg = '#C5BFB5', fg = '#1F1812' },
          c = { bg = '#E4DED0', fg = '#7A716A' },
        },
        inactive = {
          a = { bg = '#E4DED0', fg = '#7A716A' },
          b = { bg = '#E4DED0', fg = '#7A716A' },
          c = { bg = '#E4DED0', fg = '#7A716A' },
        },
      }
      require('lualine').setup({
        options = {
          theme = sky_paper,
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
          local opts = { buffer = args.buf }
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)

          -- Built-in signature help (replaces lsp_signature.nvim)
          vim.api.nvim_create_autocmd('CursorHoldI', {
            buffer = args.buf,
            callback = vim.lsp.buf.signature_help,
          })
        end,
      })

      -- mason-lspconfig auto-setup
      require('mason-lspconfig').setup({
        ensure_installed = { 'clangd', 'pyright', 'bashls', 'yamlls', 'dockerls', 'docker_compose_language_service','lua_ls','gopls'},
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
  --   CapsLock q    close it (kills the shell)
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

      -- CapsLock+t: open the terminal if it isn't showing in this tab,
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

      -- Normal mode (from the editor).
      vim.keymap.set('n', '<leader>t', smart_toggle, { desc = 'Terminal: open / focus toggle' })
      vim.keymap.set('n', '<leader>q', kill, { desc = 'Terminal: close (kill)' })
      -- Terminal mode (from inside the terminal): <leader> isn't bound there
      -- and CapsLock is F19, so match CapsLock+t / CapsLock+q directly.
      vim.keymap.set('t', '<F19>t', smart_toggle, { desc = 'Terminal: open / focus toggle' })
      vim.keymap.set('t', '<F19>q', kill, { desc = 'Terminal: close (kill)' })
    end,
  },

  {
    'kylechui/nvim-surround',
    event = 'VeryLazy',
    config = function()
      require('nvim-surround').setup({})
    end,
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
