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

	call setwinvar(popup, '&winhighlight', 'Normal:' . g:context_highlight_normal)
    call setwinvar(popup, '&wrap', 0)

    return popup
endfunction

function! context#popup#nvim#redraw(winid, popup, lines) abort
    call context#util#echof('    > context#popup#nvim#redraw', len(a:lines))

    let buf = winbufnr(a:popup)
    call nvim_buf_set_lines(buf, 0, -1, v:true, a:lines)

    let c = getwinvar(a:winid, 'context')
    call nvim_win_set_config(a:popup, {
                \ 'relative': 'editor',
                \ 'row':      c.line - 1 + c.popup_offset,
                \ 'col':      c.col - 1,
                \ 'height':   len(a:lines),
                \ 'width':    c.width,
                \ })

    call setwinvar(a:popup, '&foldcolumn', c.padding)
endfunction

function! context#popup#nvim#close(popup) abort
    call nvim_win_close(a:popup, v:true)
endfunction

function! context#popup#nvim#redraw_screen() abort
    " NOTE: this redraws the screen. this is needed because there's
    " a redraw issue: https://github.com/neovim/neovim/issues/11597
    " TODO: remove this once that issue has been resolved for some reason
    " sometimes it's not enough to :mode without :redraw we do it here because
    " it's not needed for when we call update from layout
    redraw
    mode
endfunction
