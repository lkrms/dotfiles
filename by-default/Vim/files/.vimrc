unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim

set mouse=
set ignorecase          " Case-insensitive search   (same as `:set ic`,  disable with `:set noic`)
set incsearch           " Search incrementally      (same as `:set is`,  disable with `:set nois`)
set hlsearch            " Highlight every match     (same as `:set hls`, disable with `:set nohls`)
map \ :noh<CR>          " Use '\' to disable highlighting until the next search
colorscheme slate
