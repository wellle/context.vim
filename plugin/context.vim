" context.vim
" Shows the context of the currently visible buffer contents
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

if !has('patch-7.4.1557')
    " here are some known features we use that impact what versions we can
    " support out of the box. for now we just bail out for earlier versions
    "     win_getid()     | neovim: +v0.1.5 | vim: +v7.4.1557
    "     v:vim_did_enter | neovim: +v0.1.7 | vim: +v7.4.1658
    finish
endif

call context#settings#parse()

" commands
command! -bar ContextActivate      call context#activate()
command! -bar ContextEnable        call context#enable(1)
command! -bar ContextDisable       call context#disable(1)
command! -bar ContextToggle        call context#toggle(1)
command! -bar ContextEnableWindow  call context#enable(0)
command! -bar ContextDisableWindow call context#disable(0)
command! -bar ContextToggleWindow  call context#toggle(0)
command! -bar ContextPeek          call context#peek()
command! -bar ContextUpdate        call context#update('command')


" mappings
if g:context.add_mappings
    if !exists('##WinScrolled')
        " If the WinScrolled event isn't supported we fall back to these mappings.
        nnoremap <silent> <expr> <C-Y> context#util#map('<C-Y>')
        nnoremap <silent> <expr> <C-E> context#util#map('<C-E>')
        nnoremap <silent> <expr> zz    context#util#map('zz')
        nnoremap <silent> <expr> zb    context#util#map('zb')
    endif

    " For zt and H we have extra mappings because we have to deal with the
    " height of the context.
    nnoremap <silent> <expr> zt context#util#map_zt()
    nnoremap <silent> <expr> H  context#util#map_H()
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
        autocmd OptionSet number,relativenumber,numberwidth,signcolumn,tabstop,list
                    \          call context#update('OptionSet')

        if exists('##WinScrolled')
            autocmd WinScrolled * call context#update('WinScrolled')
        endif
    augroup END
endif


" lazy loading was used
if v:vim_did_enter
    let g:context.enabled = 0 " plugin was effectively disabled before load
    ContextActivate
endif
