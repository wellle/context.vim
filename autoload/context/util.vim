function! context#util#active() abort
    return 1
                \ && g:context.enabled
                \ && w:context.enabled
                \ && !get(g:context.filetype_blacklist, &filetype)
endfunction

function! context#util#update_state() abort
    let wincount = winnr('$')
    if get(s:, 'wincount') != wincount
        let s:wincount = wincount
        let w:context.needs_layout = 1
    endif

    let top_line = line('w0')
    if w:context.top_line != top_line
        let w:context.top_line = top_line
        let w:context.needs_update = 1
    endif

    " padding can only be checked for the current window
    let padding = wincol() - virtcol('.')
    " NOTE: if 'list' is set and the cursor is on a Tab character the cursor
    " is positioned differently (at the beginning of the Tab character instead
    " of at the end). we recognize that case and fix the padding accordingly
    if &list && getline('.')[getcurpos()[2]-1] == "\t"
        let padding += &tabstop - 1
    endif
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
    if w:context.cursor_line != cursor_line
        let w:context.cursor_line = cursor_line
        let w:context.needs_move = 1
    endif
endfunction

function! context#util#update_window_state(winid) abort
    let c = getwinvar(a:winid, 'context', {})
    if c == {}
        return
    endif

    let size = [winheight(a:winid), winwidth(a:winid)]
    if [c.size_h, c.size_w] != size
        let [c.size_h, c.size_w] = size
        let c.needs_layout = 1
    endif

    if g:context.presenter != 'preview'
        let pos = win_screenpos(a:winid)
        if [c.pos_y, c.pos_x] != pos
            let [c.pos_y, c.pos_x] = pos
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
