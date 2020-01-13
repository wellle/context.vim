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

function! context#popup#nvim#update(winid, popup, lines) abort
    let buf = winbufnr(a:popup)
    call nvim_buf_set_lines(buf, 0, -1, v:true, a:lines)

    let width       = getwinvar(a:winid, 'context_width')
    let padding     = getwinvar(a:winid, 'context_padding')
    let offset      = getwinvar(a:winid, 'context_popup_offset', 0)
    let [line, col] = getwinvar(a:winid, 'context_screenpos')

    call context#util#echof('    > context#popup#nvim-update', len(a:lines))

    call nvim_win_set_config(a:popup, {
                \ 'relative': 'editor',
                \ 'row':      line - 1 + offset,
                \ 'col':      col - 1,
                \ 'height':   len(a:lines),
                \ 'width':    width,
                \ })

    call setwinvar(a:popup, '&foldcolumn', padding)
endfunction

function! context#popup#nvim#close(popup) abort
    call nvim_win_close(a:popup, v:true)
endfunction

function! context#popup#nvim#redraw() abort
    " NOTE: this redraws the screen. this is needed because there's
    " a redraw issue: https://github.com/neovim/neovim/issues/11597
    " TODO: remove this once that issue has been resolved for some reason
    " sometimes it's not enough to :mode without :redraw we do it here because
    " it's not needed for when we call update from layout
    redraw
    mode
endfunction
