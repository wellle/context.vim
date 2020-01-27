function! context#popup#vim#open() abort
    call context#util#echof('    > context#popup#vim#open')

    " NOTE: popups don't move automatically when windows get resized
    let popup = popup_create('', {
                \ 'fixed':    v:true,
                \ 'wrap':     v:false,
                \ })

    call setwinvar(popup, '&wincolor', g:context.highlight_normal)
    call setwinvar(popup, '&tabstop', &tabstop)
    call win_execute(popup, 'highlight! link FoldColumn Normal')

    return popup
endfunction

function! context#popup#vim#redraw(winid, popup, lines) abort
    call context#util#echof('    > context#popup#vim#redraw', len(a:lines))

    call popup_settext(a:popup, a:lines)

    let c = getwinvar(a:winid, 'context')
    call popup_move(a:popup, {
                \ 'line':     c.pos_y + c.popup_offset,
                \ 'col':      c.pos_x,
                \ 'minwidth': c.size_w,
                \ 'maxwidth': c.size_w,
                \ })

    call win_execute(a:popup, 'set foldcolumn=' . c.padding)
endfunction

function! context#popup#vim#close(popup) abort
    call popup_close(a:popup)
endfunction
