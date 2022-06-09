call plug#begin('~/.vim/plugged')

Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/nvim-lsp-installer', { 'branch': 'main' }
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-vsnip'
Plug 'hrsh7th/cmp-path'
Plug 'hrsh7th/cmp-buffer'

Plug 'NoahTheDuke/vim-just'
Plug 'hrsh7th/vim-vsnip'
Plug 'jiangmiao/auto-pairs'
Plug 'tomtom/tcomment_vim'

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'ellisonleao/glow.nvim'

Plug 'itchyny/lightline.vim'
Plug 'jacoborus/tender.vim'

call plug#end()

syntax on
set guifont=MonoLisa:h10

let g:mapleader=","
" let g:neovide_no_idle=v:true
" let g:neovide_refresh_rate=75

if exists("neovide")
    nmap <c-c> "+y
    vmap <c-c> "+y
    nmap <c-v> "+p
end

if (has("termguicolors"))
    set termguicolors
end

let g:lightline = { 'colorscheme': 'tender' }

syntax enable
set noshowmode

colorscheme tender

set nu rnu
set hlsearch
set tabstop=4
set expandtab
set smartindent
set shiftwidth=4

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
nnoremap <Leader>sf  <cmd>lua require'telescope.builtin'.find_files{}<CR>
nnoremap <Leader>rg  <cmd>lua require'telescope.builtin'.live_grep{}<CR>
nnoremap <Leader>cs  <cmd>lua require'telescope.builtin'.colorscheme{}<CR>

nnoremap <silent> <c-]> <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K     <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent> gD    <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent> <c-k> <cmd>lua vim.lsp.buf.signature_help()<CR>
nnoremap <silent> gD    <cmd>lua vim.lsp.buf.type_definition()<CR>
nnoremap <silent> gr    <cmd>lua vim.lsp.buf.references()<CR>
nnoremap <silent> gf    <cmd>lua vim.lsp.buf.formatting()<CR>
nnoremap <silent> g0    <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent> gW    <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
nnoremap <silent> gd    <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>
nnoremap <silent> gh    <cmd>lua vim.diagnostic.open_float(nil, { focusable = false })<CR>

nnoremap <silent> g[ <cmd>lua vim.diagnostic.goto_prev()<CR>
nnoremap <silent> g] <cmd>lua vim.diagnostic.goto_next()<CR>

set shortmess+=c
set signcolumn=yes
set completeopt=menuone,noinsert,noselect

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
