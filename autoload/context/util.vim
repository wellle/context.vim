function! context#util#active() abort
    return 1
                \ && w:context.enabled
                \ && !get(g:context.filetype_blacklist, &filetype)
endfunction

function! context#util#map_H() abort
    " TODO: handle count and scrolloff
    let w:context.force_fix_strategy = 'move'
    return 'H'
endfunction

function! context#util#map_zt() abort
    let w:context.force_fix_strategy = 'scroll'
    return "zt:call context#update('zt')\<CR>"
endfunction

function! context#util#update_state() abort
    let windows = {}
    for i in range(1, winnr('$'))
        let windows[i] = win_getid(i)
    endfor
    if g:context.windows != windows
        let g:context.windows = windows
        let w:context.needs_layout = 1
    endif

    let top_line            = line('w0')
    let cursor_line         = line('.')
    let bottom_line         = line('w$')
    let old_top_line        = w:context.top_line
    let old_cursor_line     = w:context.cursor_line
    let top_line_changed    = old_top_line != top_line
    let cursor_line_changed = old_cursor_line != cursor_line

    let c = printf('W %d T %4d%s%-4d C %4d%s%-4d B %4d', win_getid(),
                \ old_top_line,    top_line_changed    ? '->' : '  ', top_line,
                \ old_cursor_line, cursor_line_changed ? '->' : '  ', cursor_line,
                \ bottom_line,
                \ ) " context for debug logs

    " set fix_strategy
    if !cursor_line_changed && !top_line_changed
        " nothing to do
    elseif w:context.force_fix_strategy != ''
        call s:set_fix_strategy(c, '1 forced', w:context.force_fix_strategy)
        let w:context.force_fix_strategy = ''
    elseif !cursor_line_changed
        call s:set_fix_strategy(c, '2 scrolled', 'move')
    elseif !top_line_changed
        call s:set_fix_strategy(c, '3 moved', 'scroll')
    elseif cursor_line == top_line
        if cursor_line < old_cursor_line
            " NOTE: this is sometimes wrong, try L<C-F>
            " (could add mapping to fix if needed)
            call s:set_fix_strategy(c, '4 moved out top', 'scroll')
        else
            call s:set_fix_strategy(c, '5 scrolled cursor top', 'move')
        endif
    elseif cursor_line == bottom_line
        if cursor_line > old_cursor_line
            " NOTE: this is sometimes wrong, try H<C-B>
            " (could add mapping to fix if needed)
            call s:set_fix_strategy(c, '6 moved out bottom', 'scroll')
        else
            call s:set_fix_strategy(c, '7 scrolled cursor bottom', 'move')
        endif
    else " scrolled and moved with cursor in middle of screen
        " NOTE: this can happen while searching (after long jump)
        call s:set_fix_strategy(c, '8 moved middle', 'scroll')
    endif

    let w:context.top_line = top_line
    let w:context.cursor_line = cursor_line

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
endfunction

function! context#util#update_line_state() abort
    let w:context.top_line    = line('w0')
    let w:context.cursor_line = line('.')
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

function! context#util#show_cursor() abort
    " compare height of context to cursor line on screen
    let n = len(w:context.lines) - (w:context.cursor_line - w:context.top_line)
    if n <= 0
        " if cursor is low enough, nothing to do
        return
    end

    " otherwise we have to either move or scroll the cursor accordingly
    let key = (w:context.fix_strategy == 'move') ? 'j' : "\<C-Y>"
    execute 'normal! ' . n . key
    call context#util#update_line_state()
endfunction

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

function! s:set_fix_strategy(context, message, strategy) abort
    " call context#util#echof(printf('set_fix_strategy(%s)  %s -> %s', a:context, a:message, a:strategy))
    let w:context.fix_strategy = a:strategy
    let w:context.needs_update = 1
endfunction
