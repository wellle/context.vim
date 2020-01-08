function! context#util#update_state() abort
    let wincount = winnr('$')
    if get(s:, 'wincount') != wincount
        let s:wincount = wincount
        let w:context_needs_layout = 1
    endif

    let top_line = line('w0')
    let last_top_line = get(w:, 'context_top_line', 0)
    if last_top_line != top_line
        let w:context_top_line = top_line
        let w:context_needs_update = 1
    endif
    " used in preview only
    let w:context_scroll_offset = last_top_line - top_line

    " padding can only be checked for the current window
    let padding = wincol() - virtcol('.')
    if padding < 0
        " padding can be negative if cursor was on the wrapped part of a
        " wrapped line in that case don't take the new value
        " in this case we don't want to trigger an update, but still set
        " padding to a value
        if !exists('w:context_padding')
            let w:context_padding = 0
        endif
    elseif get(w:, 'context_padding', -1) != padding
        let w:context_padding = padding
        let w:context_needs_update = 1
    endif

    let cursor_line = line('.')
    let cursor_offset = cursor_line - top_line
    if get(w:, 'context_cursor_offset') != cursor_offset
        let w:context_cursor_offset = cursor_offset
        let w:context_needs_move = 1
    endif
endfunction

function! context#util#update_window_state(winid) abort
    let width = winwidth(a:winid)
    if getwinvar(a:winid, 'context_width') != width
        call setwinvar(a:winid, 'context_width', width)
        call setwinvar(a:winid, 'context_needs_layout', 1)
    endif

    let height = winheight(a:winid)
    if getwinvar(a:winid, 'context_height') != height
        call setwinvar(a:winid, 'context_height', height)
        call setwinvar(a:winid, 'context_needs_layout', 1)
    endif

    if g:context_presenter != 'preview'
        let screenpos = win_screenpos(a:winid)
        if getwinvar(a:winid, 'context_screenpos', []) != screenpos
            call setwinvar(a:winid, 'context_screenpos', screenpos)
            call setwinvar(a:winid, 'context_needs_layout', 1)
        endif
    endif
endfunction

let s:log_indent = 0

function! context#util#log_indent(amount) abort
    let s:log_indent += a:amount
endfunction

" debug logging, set g:context_logfile to activate
function! context#util#echof(...) abort
    if !exists('g:context_logfile')
        return
    endif

    let args = join(a:000)
    let args = substitute(args, "'", '"', 'g')
    let args = substitute(args, '!', '^', 'g')
    let message = repeat(' ', s:log_indent) . args
    execute "silent! !echo '" . message . "' >>" g:context_logfile
endfunction
