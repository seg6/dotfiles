set nocompatible
set noshowmode
set showmatch
set ignorecase
set hlsearch
set incsearch
set tabstop=4
set softtabstop=4
set expandtab
set shiftwidth=4
set smartindent
set rnu nu
set shortmess+=c
set signcolumn=yes
set completeopt=menuone,noinsert,noselect
set guifont=Fantasque\ Sans\ Mono:h13

call plug#begin('~/.vim/plugged')
  Plug 'hrsh7th/vim-vsnip'
  Plug 'hrsh7th/nvim-cmp'
  Plug 'hrsh7th/cmp-nvim-lsp'
  Plug 'hrsh7th/cmp-vsnip'
  Plug 'hrsh7th/cmp-path'
  Plug 'hrsh7th/cmp-buffer'
  Plug 'neovim/nvim-lspconfig'
  Plug 'p00f/clangd_extensions.nvim'
  Plug 'simrat39/rust-tools.nvim'
  Plug 'williamboman/nvim-lsp-installer', { 'branch': 'main' }

  Plug 'nvim-lua/popup.nvim'
  Plug 'nvim-lua/plenary.nvim'
  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
  Plug 'nvim-telescope/telescope.nvim'
  Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }

  Plug 'jiangmiao/auto-pairs'
  Plug 'tomtom/tcomment_vim'
  Plug 'ellisonleao/glow.nvim'

  Plug 'B4mbus/oxocarbon-lua.nvim'
  Plug 'RRethy/nvim-base16'
  Plug 'gmist/vim-palette'
  Plug 'https://gitlab.com/protesilaos/tempus-themes-vim.git'
  Plug 'nvim-lualine/lualine.nvim'
  Plug 'mhinz/vim-startify'
  Plug 'folke/twilight.nvim'
  Plug 'j-hui/fidget.nvim'
call plug#end()

if (has('termguicolors'))
  set termguicolors
end

syntax on
filetype plugin on
filetype plugin indent on

" let g:oxocarbon_lua_alternative_telescope = 1
" set background=light
" colorscheme oxocarbon-lua
" colorscheme PaperColor
" colorscheme antarctic
" colorscheme base16-embers
" colorscheme tir_black
" colorscheme tempus_classic
" colorscheme habamax
colorscheme colorsbox-stnight

let g:mapleader=','
let g:neovide_no_idle=v:true
let g:neovide_refresh_rate=75

" trigger `autoread` when files changes on disk
set autoread
autocmd FocusGained,BufEnter,CursorHold,CursorHoldI * if mode() != 'c' | checktime | endif
" notification after file change
autocmd FileChangedShellPost *
  \ echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None

" Vim jump to the last position when reopening a file
if has('autocmd')
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g'\"" | endif
endif

nmap <Leader>c "+y
vmap <Leader>c "+y
nmap <Leader>v "+p
vmap <Leader>v "+p

nnoremap <Leader>pp  <cmd>lua require'telescope.builtin'.builtin{}<CR>
nnoremap <Leader>m   <cmd>lua require'telescope.builtin'.oldfiles{}<CR>
nnoremap <Leader>a   <cmd>lua require'telescope.builtin'.buffers{}<CR>
nnoremap <Leader>/   <cmd>lua require'telescope.builtin'.current_buffer_fuzzy_find{}<CR>
nnoremap <Leader>'   <cmd>lua require'telescope.builtin'.marks{}<CR>
nnoremap <Leader>d   <cmd>lua require'telescope.builtin'.git_files{}<CR>
nnoremap <Leader>f   <cmd>lua require'telescope.builtin'.find_files{}<CR>
nnoremap <Leader>g   <cmd>lua require'telescope.builtin'.live_grep{}<CR>
nnoremap <Leader>cs  <cmd>lua require'telescope.builtin'.colorscheme{}<CR>

nnoremap <Leader>ss :SSave<CR>
nnoremap <Leader>sd :SClose<CR>

nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K     <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent> gi    <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
nnoremap <silent> gt    <cmd>lua vim.lsp.buf.type_definition()<CR>
nnoremap <silent> gr    <cmd>lua vim.lsp.buf.references()<CR>
nnoremap <silent> gf    <cmd>lua vim.lsp.buf.format()<CR>
nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent> gW    <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
nnoremap <silent> gd    <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>
nnoremap <silent> gh    <cmd>lua vim.diagnostic.open_float(nil, { focusable = false })<CR>

nnoremap <silent> g[ <cmd>lua vim.diagnostic.goto_prev()<CR>
nnoremap <silent> g] <cmd>lua vim.diagnostic.goto_next()<CR>

let g:startify_custom_header = []
let g:startify_lists = [
  \ { 'type': 'sessions', 'header': ['Sessions'] }
  \ ]

lua <<EOF
local nvim_lsp = require('lspconfig')
local lsp_installer = require('nvim-lsp-installer')

lsp_installer.on_server_ready(function(server)
  server:setup({})
end)
EOF

lua <<EOF
require('rust-tools').setup({
    server = {
    }
})
require('fidget').setup({})
require('twilight').setup({})
require('clangd_extensions').setup()

local cmp = require('cmp')

cmp.setup({
  -- Enable LSP snippets
  snippet = {
    expand = function(args)
      vim.fn['vsnip#anonymous'](args.body)
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
      select = true,
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

local theme = require('lualine.themes.auto')
local bgcol = '#1d1f21'

theme.normal.a.fg = theme.normal.a.bg;
theme.normal.a.bg = bgcol
theme.normal.b.bg = bgcol
theme.normal.c.bg = bgcol

theme.insert.a.fg = theme.insert.a.bg;
theme.insert.a.bg = bgcol
theme.insert.b.bg = bgcol
theme.insert.c.bg = bgcol

theme.visual.a.fg = theme.visual.a.bg;
theme.visual.a.bg = bgcol
theme.visual.b.bg = bgcol
theme.visual.c.bg = bgcol

theme.replace.a.fg = theme.replace.a.bg;
theme.replace.a.bg = bgcol
theme.replace.b.bg = bgcol
theme.replace.c.bg = bgcol

theme.command.a.fg = theme.command.a.bg;
theme.command.a.bg = bgcol
theme.command.b.bg = bgcol
theme.command.c.bg = bgcol

require('lualine').setup{
  options = {
    theme = theme,
    icons_enabled = false,
  }
}

require('telescope').setup {
  extensions = {
    fzf = {
      fuzzy = true,                    -- false will only do exact matching
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = 'smart_case',        -- or "ignore_case" or "respect_case"
                                       -- the default case_mode is "smart_case"
    }
  }
}

require('nvim-treesitter.configs').setup {
  ensure_installed = { 'c', 'cpp', 'rust', 'python', 'c_sharp' },
  auto_install = true,

  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}
EOF
