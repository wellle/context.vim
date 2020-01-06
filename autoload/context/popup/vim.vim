
function! context#popup#vim#open() abort
    call context#util#echof('    > vim_open_popup')

    " NOTE: popups don't move automatically when windows get resized
    let popup = popup_create('', {
                \ 'wrap':     v:false,
                \ 'fixed':    v:true,
                \ })

	call setwinvar(popup, '&wincolor', g:context_highlight_normal)
    call setwinvar(popup, '&tabstop', &tabstop)

    return popup
endfunction

function! context#popup#vim#update(winid, popup, lines) abort
    call context#util#echof('    > vim_update_popup', len(a:lines))
    call popup_settext(a:popup, a:lines)

    let width   = getwinvar(a:winid, 'context_width')
    let padding = getwinvar(a:winid, 'context_padding')

    let [line, col] = getwinvar(a:winid, 'context_screenpos')
    call popup_move(a:popup, {
                \ 'line':     line,
                \ 'col':      col,
                \ 'minwidth': width,
                \ 'maxwidth': width,
                \ })

	call win_execute(a:popup, 'set foldcolumn=' . padding)
endfunction

function! context#popup#vim#close(popup) abort
    call popup_close(a:popup)
endfunction
