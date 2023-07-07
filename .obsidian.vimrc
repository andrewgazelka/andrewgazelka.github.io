" Have j and k navigate visual lines rather than logical ones
nmap j gj
nmap k gk

" nmap n nzt
" nmap N Nzt

" I like using H and L for beginning/end of line
nmap H ^
nmap L $
" Quickly remove search highlights
nmap <F9> :nohl

" Yank to system clipboard
set clipboard=unnamed

" Go back and forward with Ctrl+O and Ctrl+I
" (make sure to remove default Obsidian shortcuts for these to work)
exmap back obcommand app:go-back
nmap <C-o> :back
exmap forward obcommand app:go-forward
nmap <C-i> :forward


exmap unfoldall obcommand editor:unfold-all
nmap zR :unfoldall
nmap zO :unfoldall

exmap foldall obcommand editor:fold-all
nmap zM :foldall
nmap zC :foldall


" exmap foldtoggle obcommand editor:toggle-fold
" nmap za :foldtoggle
"
" Emulate Folding https://vimhelp.org/fold.txt.html#fold-commands
exmap togglefold obcommand editor:toggle-fold
nmap zo :togglefold
nmap zc :togglefold
nmap za :togglefold
