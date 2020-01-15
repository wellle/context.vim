function! context#util#update_state() abort
    let wincount = winnr('$')
    if get(s:, 'wincount') != wincount
        let s:wincount = wincount
        let w:context.needs_layout = 1
    endif

    let top_line = line('w0')
    let last_top_line = w:context.top_line
    if last_top_line != top_line
        let w:context.top_line = top_line
        let w:context.needs_update = 1
    endif
    " used in preview only
    let w:context.scroll_offset = last_top_line - top_line

    " padding can only be checked for the current window
    let padding = wincol() - virtcol('.')
    if padding < 0
        " padding can be negative if cursor was on the wrapped part of a
        " wrapped line in that case don't take the new value
        " in this case we don't want to trigger an update, but still set
        " padding to a value
        if !exists('w:context.padding')
            let w:context.padding = 0
        endif
    elseif w:context.padding != padding
        let w:context.padding = padding
        let w:context.needs_update = 1
    endif

    let cursor_line = line('.')
    let cursor_offset = cursor_line - top_line
    if w:context.cursor_offset != cursor_offset
        let w:context.cursor_offset = cursor_offset
        let w:context.needs_move = 1
    endif
endfunction

function! context#util#update_window_state(winid) abort
    let c = getwinvar(a:winid, 'context')

    let width = winwidth(a:winid)
    if c.width != width
        let c.width = width
        let c.needs_layout = 1
    endif

    let height = winheight(a:winid)
    if c.height != height
        let c.height = height
        let c.needs_layout = 1
    endif

    if g:context.presenter != 'preview'
        let [line, col] = win_screenpos(a:winid)
        if c.line != line || c.col != col
            let c.line = line
            let c.col  = col
            let c.needs_layout = 1
        endif
    endif
endfunction

let s:log_indent = 0

function! context#util#log_indent(amount) abort
    let s:log_indent += a:amount
endfunction

" debug logging, set g:context.logfile to activate
function! context#util#echof(...) abort
    if g:context.logfile == ''
        return
    endif

    let args = join(a:000)
    let args = substitute(args, "'", '"', 'g')
    let args = substitute(args, '!', '^', 'g')
    let args = substitute(args, '#', '+', 'g')
    let message = repeat(' ', s:log_indent) . args
    execute "silent! !echo '" . message . "' >>" g:context.logfile
endfunction
