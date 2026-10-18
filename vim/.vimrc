set nocompatible
if exists('#filetypedetect')
  filetype off
endif
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'

Plugin 'mhartington/oceanic-next'
Plugin 'tmhedberg/SimpylFold'
Plugin 'vim-scripts/indentpython.vim'
Plugin 'vim-syntastic/syntastic'
Plugin 'nvie/vim-flake8'
Plugin 'scrooloose/nerdtree'
Plugin 'jistr/vim-nerdtree-tabs'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'zxqfl/tabnine-vim'
Plugin 'frazrepo/vim-rainbow'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'davidhalter/jedi-vim'
Plugin 'Valloric/YouCompleteMe'
Plugin 'hashivim/vim-terraform'
Plugin 'townk/vim-autoclose'
Plugin 'rust-lang/rust.vim'
Plugin 'fatih/vim-go'
Plugin 'maralla/completor.vim'
Plugin 'vim-scripts/bash-support.vim'
Plugin 'godlygeek/tabular'
Plugin 'andrewstuart/vim-kubernetes'
Plugin 'gabrielelana/vim-markdown'
Plugin 'morhetz/gruvbox'
Plugin 'lervag/vimtex'
Plugin 'yorinasub17/vim-terragrunt'
Plugin 'dense-analysis/ale'

call vundle#end()
filetype plugin indent on

set splitbelow
set splitright
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

set foldmethod=indent
set foldlevel=99
nnoremap <space> za

autocmd FileType python setlocal tabstop=256 softtabstop=2 shiftwidth=2 textwidth=79 expandtab autoindent fileformat=unix
autocmd FileType javascript,html,css setlocal tabstop=2 softtabstop=2 shiftwidth=2

let g:vim_header_author = get(g:, 'vim_header_author', 'YOUR NAME')

function! s:SourceHeader(extension) abort
  let l:comment = index(['py', 'pyw', 'pl', 'pm', 'rb'], a:extension) >= 0 ? '#' : '//'
  let l:shebangs = {
        \ 'py': '#!/usr/bin/env python3',
        \ 'pyw': '#!/usr/bin/env python3',
        \ 'pl': '#!/usr/bin/env perl',
        \ 'rb': '#!/usr/bin/env ruby'
        \ }
  let l:header = []

  if has_key(l:shebangs, a:extension)
    call add(l:header, l:shebangs[a:extension])
  endif

  call add(l:header, l:comment . ' ' . repeat('=', 77))
  call add(l:header, l:comment . ' FILE: ' . expand('%:t'))
  call add(l:header, l:comment . ' DESCRIPTION:')
  call add(l:header, l:comment . ' AUTHOR: ' . g:vim_header_author)
  call add(l:header, l:comment . ' CREATED: ' . strftime('%Y-%m-%d %H:%M:%S'))
  call add(l:header, l:comment . ' ' . repeat('=', 77))
  call add(l:header, '')
  return l:header
endfunction

function! s:AddSourceHeader() abort
  call setline(1, s:SourceHeader(expand('%:e')))
endfunction

function! s:AddGoSourceHeader() abort
  if exists('b:vim_source_header_pending') && !exists('b:vim_source_header_added')
    call append(0, s:SourceHeader('go'))
    let b:vim_source_header_added = 1
    unlet b:vim_source_header_pending
  endif
endfunction

autocmd BufNewFile *.py,*.pyw,*.pl,*.pm,*.rb,*.java,*.rs call <SID>AddSourceHeader()
autocmd BufNewFile *.go let b:vim_source_header_pending = 1
autocmd BufEnter *.go call <SID>AddGoSourceHeader()

au FileType yaml nmap <leader>r :KubeApply<CR>
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab

let g:ale_linters = {
\   'yaml': ['yamllint'],
\}
let g:ale_lint_on_text_changed = 'always'
let g:ale_lint_on_insert_leave = 1

highlight BadWhitespace ctermbg=red guibg=darkred
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

let g:ycm_autoclose_preview_window_after_completion=1
map <leader>g :YcmCompleter GoToDefinitionElseDeclaration<CR>

let python_highlight_all=1
syntax on
let g:ale_python_flake8_options = '--ignore=D400'

let NERDTreeIgnore=['\.pyc$', '\~$']
set number
set relativenumber
let g:rainbow_active = 1

syntax enable
set t_Co=256
if has("termguicolors")
  set termguicolors
endif
if !empty(globpath(&runtimepath, 'colors/gruvbox.vim'))
  colorscheme gruvbox
endif
set background=dark
set cursorline
set cursorcolumn
set list
set listchars=tab:--,trail:·,extends:»,precedes:-
set shiftwidth=2
set backspace=2
set incsearch
set hlsearch
set expandtab
set softtabstop=2

if filereadable(expand('~/.vim/yaml.vim'))
  au BufNewFile,BufRead *.yaml,*.yml source ~/.vim/yaml.vim
endif

let g:completor_filetype_map = {}
let g:completor_filetype_map.go = {'ft': 'lsp', 'cmd': 'gopls -remote=auto'}
let g:go_bin_path = $HOME . "/go/bin"

set spell
set spelllang=pt_br
autocmd FileType markdown,text,tex setlocal spell spelllang=pt_br
autocmd BufRead,BufNewFile *.txt setlocal spell spelllang=pt_br

highlight clear SpellBad
highlight SpellBad cterm=underline ctermfg=red guifg=#FF0000 gui=undercurl

let g:ale_linters = {
    \ 'sh': ['shellcheck', 'camelcase']
\ }
let g:ale_fixers = {
    \ 'sh': []
\ }
let g:ale_sh_camelcase_executable = '~/bin/camelcase_linter.sh'
let g:ale_sh_camelcase_options = ''

set encoding=utf-8
