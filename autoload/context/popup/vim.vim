function! context#popup#vim#open() abort
    call context#util#echof('    > context#popup#vim#open')

    " NOTE: popups don't move automatically when windows get resized
    let popup = popup_create('', {
                \ 'fixed':    v:true,
                \ 'wrap':     v:false,
                \ })

    call setwinvar(popup, '&wincolor', g:context.highlight_normal)

    return popup
endfunction

function! context#popup#vim#redraw(winid, popup, lines) abort
    call context#util#echof('    > context#popup#vim#redraw', len(a:lines))

    call popup_settext(a:popup, a:lines)

    let c = getwinvar(a:winid, 'context')
    call popup_move(a:popup, {
                \ 'line':     c.pos_y,
                \ 'col':      c.pos_x,
                \ 'minwidth': c.size_w,
                \ 'maxwidth': c.size_w,
                \ })

    call win_execute(a:popup, 'let &list=' . &list)
    call win_execute(a:popup, 'call clearmatches()')
endfunction

function! context#popup#vim#close(popup) abort
    call popup_close(a:popup)
endfunction
