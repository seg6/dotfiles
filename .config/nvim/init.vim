set guifont=MonoLisa:h10
set shortmess+=c
set signcolumn=yes
set completeopt=menuone,noinsert,noselect

set nu rnu
set hlsearch
set tabstop=4
set expandtab
set noshowmode
set smartindent
set shiftwidth=4

if (has("termguicolors"))
    set termguicolors
end

syntax enable

call plug#begin('~/.vim/plugged')

Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-buffer'
Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/nvim-lsp-installer', { 'branch': 'main' }

Plug 'NoahTheDuke/vim-just'
Plug 'hrsh7th/vim-vsnip'
Plug 'jiangmiao/auto-pairs'
Plug 'tomtom/tcomment_vim'
Plug 'ellisonleao/glow.nvim'

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }

Plug 'nvim-lualine/lualine.nvim'
Plug 'nekonako/xresources-nvim'
Plug 'AlphaTechnolog/pywal.nvim', { 'as': 'pywal' }

Plug 'folke/twilight.nvim'
Plug 'j-hui/fidget.nvim'

call plug#end()

colorscheme xresources

let g:mapleader=","
let g:neovide_no_idle=v:true
let g:neovide_refresh_rate=75

if exists("neovide")
    nmap <c-c> "+y
    vmap <c-c> "+y
    nmap <c-v> "+p
end

" trigger `autoread` when files changes on disk
set autoread
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif
" notification after file change
autocmd FileChangedShellPost *
    \ echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None

nnoremap <Leader>pp  <cmd>lua require'telescope.builtin'.builtin{}<CR>
nnoremap <Leader>m   <cmd>lua require'telescope.builtin'.oldfiles{}<CR>
nnoremap <Leader>;   <cmd>lua require'telescope.builtin'.buffers{}<CR>
nnoremap <Leader>/   <cmd>lua require'telescope.builtin'.current_buffer_fuzzy_find{}<CR>
nnoremap <Leader>'   <cmd>lua require'telescope.builtin'.marks{}<CR>
nnoremap <Leader>f   <cmd>lua require'telescope.builtin'.git_files{}<CR>
nnoremap <Leader>d   <cmd>lua require'telescope.builtin'.find_files{}<CR>
nnoremap <Leader>g   <cmd>lua require'telescope.builtin'.live_grep{}<CR>
nnoremap <Leader>cs  <cmd>lua require'telescope.builtin'.colorscheme{}<CR>

nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K     <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent> gi    <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
nnoremap <silent> gt    <cmd>lua vim.lsp.buf.type_definition()<CR>
nnoremap <silent> gr    <cmd>lua vim.lsp.buf.references()<CR>
nnoremap <silent> gf    <cmd>lua vim.lsp.buf.formatting()<CR>
nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent> gW    <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
nnoremap <silent> gd    <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>
nnoremap <silent> gh    <cmd>lua vim.diagnostic.open_float(nil, { focusable = false })<CR>

nnoremap <silent> g[ <cmd>lua vim.diagnostic.goto_prev()<CR>
nnoremap <silent> g] <cmd>lua vim.diagnostic.goto_next()<CR>

lua <<EOF
require('telescope').setup {
    extensions = {
        fzf = {
            fuzzy = true,                    -- false will only do exact matching
            override_generic_sorter = true,  -- override the generic sorter
            override_file_sorter = true,     -- override the file sorter
            case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
                                             -- the default case_mode is "smart_case"
        }
    }
}

require('telescope').load_extension('fzf')
EOF

lua <<EOF
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, {
        virtual_text = {
            spacing = 1,
        },
        underline = true,
    }
)

local nvim_lsp = require'lspconfig'
local lsp_installer = require("nvim-lsp-installer")

lsp_installer.on_server_ready(function(server)
    server:setup({})
end)
EOF

lua <<EOF
local cmp = require'cmp'

cmp.setup({
    -- Enable LSP snippets
    snippet = {
        expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
        end,
    },
    mapping = {
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-n>'] = cmp.mapping.select_next_item(),
        -- Add tab support
        ['<S-Tab>'] = cmp.mapping.select_prev_item(),
        ['<Tab>'] = cmp.mapping.select_next_item(),
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.close(),
        ['<CR>'] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Insert,
            select = false,
        })
    },

    -- Installed sources
    sources = {
        { name = 'nvim_lsp' },
        { name = 'vsnip' },
        { name = 'path' },
        { name = 'buffer' },
    },
})
EOF

lua << EOF
    require"fidget".setup{}
EOF

lua << EOF
  require("twilight").setup {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  }
EOF

lua << EOF
require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'pywal',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
EOF
