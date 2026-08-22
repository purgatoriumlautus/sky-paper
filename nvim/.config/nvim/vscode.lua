-- Loaded INSTEAD of init.lua when Neovim runs embedded inside VSCode
-- (the vscode-neovim extension sets vim.g.vscode). Dispatched from
-- init.lua line 1.
--
-- Nothing here loads plugins: VSCode owns the UI. This file only
-- reproduces the keybinding scheme so muscle memory does not switch
-- between this machine and the work Mac. Full scheme: docs/keybinds.md
--
-- Split of responsibility on the Mac:
--   this file            <leader> tier — actions inside the editor
--   VSCode keybindings   Alt tier — container borders, lists, terminal
--                        (docs/vscode/keybindings.json)
--
-- Why the Alt tier is NOT here: inside the VSCode terminal, Neovim is not
-- running at all, so only VSCode itself can catch those keys.

local ok, vscode = pcall(require, 'vscode')
if not ok then return end

local function cmd(command)
  return function() vscode.action(command) end
end

-- ===================
-- Settings that still matter with VSCode drawing the screen
-- ===================
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.clipboard = 'unnamedplus'

-- Same layout-independence as the real config: with the Russian layout
-- active, normal/visual/operator-pending keys act by physical position.
vim.opt.langmap = 'ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz'

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- ===================
-- Top level
-- ===================
map('n', '<leader><leader>', cmd('workbench.action.quickOpen'),        'Find file')
map('n', '<leader>,',        cmd('workbench.action.showAllEditors'),   'Switch buffer')
map('n', '<leader>/',        cmd('workbench.action.findInFiles'),      'Grep project')
map('n', '<leader>:',        cmd('workbench.action.showCommands'),     'Command palette')
map('n', '<leader>w',        cmd('workbench.action.files.save'),       'Write file')
map('n', '<leader>q',        cmd('workbench.action.closeActiveEditor'),'Close buffer')
map('n', '<leader>e',        cmd('workbench.view.explorer'),           'File tree')
map('n', '<leader>n',        cmd('workbench.action.toggleSidebarVisibility'), 'Toggle sidebar')
map('n', '<leader>d',        cmd('workbench.action.showAllEditors'),   'Overview')

-- ===================
-- f — find
-- ===================
map('n', '<leader>ff', cmd('workbench.action.quickOpen'),           'Files')
map('n', '<leader>fg', cmd('workbench.action.findInFiles'),         'Grep')
map('n', '<leader>fb', cmd('workbench.action.showAllEditors'),      'Buffers')
map('n', '<leader>fr', cmd('workbench.action.openRecent'),          'Recent')
map('n', '<leader>fs', cmd('workbench.action.gotoSymbol'),          'Symbols in file')
map('n', '<leader>fh', cmd('workbench.action.showCommands'),        'Help / commands')
map('n', '<leader>fk', cmd('workbench.action.openGlobalKeybindings'), 'All keymaps')

-- ===================
-- g — git
-- ===================
map('n', '<leader>gg', cmd('workbench.view.scm'),                  'Git panel')
map('n', '<leader>gs', cmd('workbench.view.scm'),                  'Git status')
map('n', '<leader>gd', cmd('git.openChange'),                      'Diff current file')
map('n', '<leader>gb', cmd('gitlens.toggleFileBlame'),             'Blame')
map('n', '<leader>gp', cmd('editor.action.dirtydiff.next'),        'Preview hunk')
map('n', '<leader>gr', cmd('git.revertSelectedRanges'),            'Reset hunk')
map('n', '<leader>gS', cmd('git.stageSelectedRanges'),             'Stage hunk')

-- ===================
-- c — code
-- ===================
map('n', '<leader>ca', cmd('editor.action.quickFix'),          'Code action')
map('n', '<leader>cr', cmd('editor.action.rename'),            'Rename symbol')
map('n', '<leader>cf', cmd('editor.action.formatDocument'),    'Format buffer')
map('n', '<leader>cd', cmd('editor.action.showHover'),         'Line diagnostics')
map('n', '<leader>cs', cmd('workbench.action.gotoSymbol'),     'Symbols in file')
map('x', '<leader>cf', cmd('editor.action.formatSelection'),   'Format selection')
map('x', '<leader>ca', cmd('editor.action.quickFix'),          'Code action')

-- ===================
-- b — buffers
-- ===================
map('n', '<leader>bd', cmd('workbench.action.closeActiveEditor'),  'Close buffer')
map('n', '<leader>bo', cmd('workbench.action.closeOtherEditors'),  'Close others')
map('n', '<leader>bb', cmd('workbench.action.openPreviousRecentlyUsedEditorInGroup'), 'Previous buffer')

-- ===================
-- x — problems
-- ===================
map('n', '<leader>xx', cmd('workbench.actions.view.problems'), 'Diagnostics')
map('n', '<leader>xw', cmd('workbench.actions.view.problems'), 'Diagnostics: workspace')
map('n', '<leader>xq', cmd('workbench.actions.view.problems'), 'Quickfix')

-- ===================
-- u — ui
-- ===================
map('n', '<leader>uw', cmd('editor.action.toggleWordWrap'),          'Toggle wrap')
map('n', '<leader>un', cmd('editor.action.toggleRenderLineNumbers'), 'Toggle line numbers')
map('n', '<leader>ut', cmd('workbench.action.selectTheme'),          'Theme')

-- ===================
-- Bare keys — same as the real config
-- ===================
map('n', 'gd', cmd('editor.action.revealDefinition'),  'Go to definition')
map('n', 'gr', cmd('editor.action.goToReferences'),    'References')
map('n', 'K',  cmd('editor.action.showHover'),         'Hover')
map('n', ']d', cmd('editor.action.marker.next'),       'Next diagnostic')
map('n', '[d', cmd('editor.action.marker.prev'),       'Prev diagnostic')
map('n', ']c', cmd('workbench.action.editor.nextChange'),     'Next hunk')
map('n', '[c', cmd('workbench.action.editor.previousChange'), 'Prev hunk')
map('n', '<S-l>', cmd('workbench.action.nextEditor'),     'Next buffer')
map('n', '<S-h>', cmd('workbench.action.previousEditor'), 'Previous buffer')

-- Visual-mode paste keeps the yank register (same as init.lua)
map('x', 'p', '"_dP', 'Paste over selection without clobbering register')

map('n', '<Esc>', '<cmd>nohlsearch<CR>', 'Clear search highlight')

-- Arrows off, hjkl only (same as init.lua)
for _, k in ipairs({ '<Up>', '<Down>', '<Left>', '<Right>' }) do
  map('n', k, '<Nop>')
end
