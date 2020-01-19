" context.vim
" Shows the context of the currently visible buffer contents
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

" TODO: update docs for new settings

call context#settings#parse()

" commands
command! -bar ContextActivate call context#activate()
command! -bar ContextEnable   call context#enable()
command! -bar ContextDisable  call context#disable()
command! -bar ContextToggle   call context#toggle()
command! -bar ContextUpdate   call context#update('command')


" TODO update docs, as we changed the mappings and autocmds

" mappings
if g:context.add_mappings
    " NOTE: in the zz/zt/zb mappings we invoke zz/zt/zb twice before calling
    " context#update(). unfortunately this is needed because it seems like Vim
    " sometimes gets confused if the window height changes shortly after zz/zt/zb
    " have been executed.
    nnoremap <silent>        <C-Y> <C-Y>:call context#update('C-Y')<CR>
    nnoremap <silent>        zz     zzzz:call context#update('zz')<CR>
    nnoremap <silent>        zb     zbzb:call context#update('zb')<CR>
    nnoremap <silent> <expr> <C-E>            context#mapping#ce()
    nnoremap <silent> <expr> zt               context#mapping#zt()
    nnoremap <silent> <expr> k                context#mapping#k()
    nnoremap <silent> <expr> H                context#mapping#h()
endif


" autocommands
if g:context.add_autocmds
    augroup context.vim
        autocmd!
        autocmd VimEnter     * ContextActivate
        autocmd BufAdd       * call context#update('BufAdd')
        autocmd BufEnter     * call context#update('BufEnter')
        autocmd CursorMoved  * call context#update('CursorMoved')
        autocmd VimResized   * call context#update('VimResized')
        autocmd CursorHold   * call context#update('CursorHold')
        autocmd User GitGutter call context#update('GitGutter')

    augroup END
endif

" lazy loading was used
if v:vim_did_enter
    let g:context_enabled = 0 " plugin was effectively disabled before load
    ContextActivate
endif
