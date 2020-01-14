function! context#popup#vim#open() abort
    call context#util#echof('    > context#popup#vim#open')

    " NOTE: popups don't move automatically when windows get resized
    let popup = popup_create('', {
                \ 'fixed':    v:true,
                \ 'wrap':     v:false,
                \ })

	call setwinvar(popup, '&wincolor', g:context_highlight_normal)
    call setwinvar(popup, '&tabstop', &tabstop)

    return popup
endfunction

function! context#popup#vim#redraw(winid, popup, lines) abort
    call popup_settext(a:popup, a:lines)

    let width       = getwinvar(a:winid, 'context_width')
    let padding     = getwinvar(a:winid, 'context_padding')
    let offset      = getwinvar(a:winid, 'context_popup_offset', 0)
    let [line, col] = getwinvar(a:winid, 'context_screenpos')

    call context#util#echof('    > context#popup#vim#redraw', len(a:lines))

    call popup_move(a:popup, {
                \ 'line':     line + offset,
                \ 'col':      col,
                \ 'minwidth': width,
                \ 'maxwidth': width,
                \ })

	call win_execute(a:popup, 'set foldcolumn=' . padding)
endfunction

function! context#popup#vim#close(popup) abort
    call popup_close(a:popup)
endfunction
