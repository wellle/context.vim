function! context#popup#nvim#open() abort
    call context#util#echof('    > nvim_open_popup')

    let buf = nvim_create_buf(v:false, v:true)
    " TODO: maybe use relative:editor to be more similar to vim popups?
    let popup = nvim_open_win(buf, 0, {
                \ 'relative':  'win',
                \ 'width':     1,
                \ 'height':    1,
                \ 'row':       0,
                \ 'col':       0,
                \ 'focusable': v:false,
                \ 'anchor':    'NW',
                \ 'style':     'minimal',
                \ })

	call setwinvar(popup, '&winhighlight', 'Normal:' . g:context_highlight_normal)
    call setwinvar(popup, '&wrap', 0)

    return popup
endfunction

function! context#popup#nvim#update(winid, popup, lines) abort
    call context#util#echof('    > nvim_update_popup', len(a:lines))

    let width   = getwinvar(a:winid, 'context_width')
    let padding = getwinvar(a:winid, 'context_padding')
    let offset  = getwinvar(a:winid, 'context_popup_offset', 0)
    let buf     = winbufnr(a:popup)

    call nvim_buf_set_lines(buf, 0, -1, v:true, a:lines)
    call nvim_win_set_config(a:popup, {
                \ 'relative': 'win',
                \ 'height':   len(a:lines),
                \ 'width':    width,
                \ 'row':      offset,
                \ 'col':      0,
                \ })

    call setwinvar(a:popup, '&foldcolumn', padding)
endfunction

function! context#popup#nvim#close(popup) abort
    call nvim_win_close(a:popup, v:true)
endfunction

function! context#popup#nvim#redraw() abort
    " NOTE: this redraws the screen. this is needed because there's
    " a redraw issue: https://github.com/neovim/neovim/issues/11597
    " TODO: remove this once that issue has been resolved
    " for some reason sometimes it's not enough to :mode without :redraw
    " we do it here because it's not needed for when we call
    " popup_update from update_layout
    redraw
    mode
endfunction
