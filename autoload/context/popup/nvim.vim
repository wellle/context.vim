function! context#popup#nvim#open() abort
    call context#util#echof('    > context#popup#nvim#open')

    let buf = nvim_create_buf(v:false, v:true)
    let popup = nvim_open_win(buf, 0, {
                \ 'relative':  'editor',
                \ 'row':       0,
                \ 'col':       0,
                \ 'width':     1,
                \ 'height':    1,
                \ 'focusable': v:false,
                \ 'style':     'minimal',
                \ })

    call setwinvar(popup, '&wrap', 0)
    call setwinvar(popup, '&foldenable', 0)
    call setwinvar(popup, '&tabstop', &tabstop)
    call setwinvar(popup, '&winhighlight', 'Normal:' . g:context.highlight_normal)

    return popup
endfunction

function! context#popup#nvim#redraw(winid, popup, lines) abort
    let buf = winbufnr(a:popup)
    call context#util#echof('    > context#popup#nvim#redraw', len(a:lines), a:winid, buf)

    " NOTE: again we need to do a workaround because of the neovim bug
    " neovim#11878. to reproduce open a buffer with visible context and then
    " open a new buffer in a split (with cursor on a line without visible
    " context). at the time of one of the autocommands the new window appears
    " to context.vim to hold the previous buffer which leads to an E12 error
    " from #popup#layout()
    let v:errmsg = ""
    silent! call nvim_buf_set_lines(buf, 0, -1, v:true, a:lines)
    if v:errmsg != ""
        return
    endif

    let c = getwinvar(a:winid, 'context')
    call nvim_win_set_config(a:popup, {
                \ 'relative': 'editor',
                \ 'row':      c.pos_y - 1,
                \ 'col':      c.pos_x - 1,
                \ 'height':   len(a:lines),
                \ 'width':    c.size_w,
                \ })

    call setwinvar(a:popup, '&list', &list)

    " NOTE: because of some neovim limitation we have to temporarily switch to
    " the popup window so we can clear the highlighting
    " https://github.com/neovim/neovim/issues/10822
    execute 'noautocmd' bufwinnr(buf) . 'wincmd w'
    call clearmatches()
    wincmd p
endfunction

function! context#popup#nvim#close(popup) abort
    call nvim_win_close(a:popup, v:true)
endfunction

function! context#popup#nvim#redraw_screen() abort
    " NOTE: In earlier versions of Neovim there was an issue with redrawing
    " popup. This has been fixed as of this minor version.
    if has('nvim-0.5.0')
        return
    endif

    if g:context.nvim_no_redraw
        return
    endif

    " On older versions we need to call :mode to force a hard redraw. In some
    " cases we an additional call do :redraw is needed too.
    redraw
    mode
endfunction
