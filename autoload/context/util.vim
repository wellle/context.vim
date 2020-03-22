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

    let top_line    = line('w0')
    let bottom_line = line('w$')
    let cursor_line = line('.')

    let winid = win_getid()

    let old_top_line = w:context.top_line
    let old_bottom_line = w:context.bottom_line
    let old_cursor_line = w:context.cursor_line

    let top_diff = old_top_line - top_line
    let bottom_diff = old_bottom_line - bottom_line
    let cursor_diff = old_cursor_line - cursor_line

    let top_line_changed = top_diff != 0
    let bottom_line_changed = bottom_diff != 0
    let cursor_line_changed = cursor_diff != 0

    if top_line_changed || bottom_line_changed || cursor_line_changed
        call context#util#echof('xxx  ', winid, '|', old_top_line, top_line, '|', old_cursor_line, cursor_line, '|', old_bottom_line, bottom_line)
        if old_top_line == 0
            " TODO: do we need this special case? maybe not, check later
            " we don't really need it. if we remove it we will run into case 7
            " below (cursor line and top line changed), which is considered a
            " move, so we would scroll to fix anyway
            call context#util#echof('xxx 2 new: scroll')
            let w:context.fix_strategy = 'scroll'
        elseif cursor_line_changed
            if top_line_changed
                if cursor_line == top_line
                    if cursor_line < old_cursor_line
                        " move cursor up out of sight
                        " NOTE: this is also sometimes wrong
                        " try L<C-F>
                        " we should be able to detect that! (cursor moves one line up)
                        " might be fine though, TODO check later
                        call context#util#echof('xxx 3 moved')
                        let w:context.fix_strategy = 'scroll'
                    else
                        " scroll down while cursor is on top line
                        call context#util#echof('xxx 4 scrolled')
                        let w:context.fix_strategy = 'move'
                    endif
                elseif cursor_line == bottom_line
                    if cursor_line > old_cursor_line
                        " move cursor down out of sight
                        " NOTE: this is also sometimes wrong
                        " try H<C-B>
                        " we should be able to detect that! (cursor moves one line down)
                        " might be fine though, TODO check later
                        call context#util#echof('xxx 5 moved')
                        let w:context.fix_strategy = 'scroll'
                    else
                        " scroll up while cursor is on bottom line
                        call context#util#echof('xxx 6 scrolled')
                        let w:context.fix_strategy = 'move'
                    endif
                else " cursor in middle of screen
                    " TODO: this case is kinda weird, wouldn't expect to happen, but
                    " happens while searching. if vim decides to move cursor
                    " to top. then both corsor has changed and screen has
                    " scrolled
                    " so maybe we should switch it to be consider a cursor
                    " move...? probably
                    " or is there any other way to trigger this?
                    " probably not. if scrolled then either the cursor doesn't
                    " move or is at top/bottom line because it was forced
                    " there
                    call context#util#echof('xxx 7 moved')
                    let w:context.fix_strategy = 'scroll'
                endif
            else " !top_line_changed
                call context#util#echof('xxx 9 moved')
                let w:context.fix_strategy = 'scroll'
            endif
        else " !cursor_line_changed
            if top_line_changed
                call context#util#echof('xxx 11 scrolled')
                let w:context.fix_strategy = 'move'
            elseif bottom_line_changed
                " TODO: avoid this case, happens when scrolling too with wrap
                call context#util#echof('xxx 12 resized: scroll')
                let w:context.fix_strategy = 'move'
            else " nothing changed
                " TODO: can we trigger this case? probably not and we can set
                " the var to whatever
                call context#util#echof('xxx 13 TODO')
                let w:context.fix_strategy = 'scroll'
            endif
        endif
    endif

    if w:context.force_fix_strategy != ''
        let w:context.fix_strategy = w:context.force_fix_strategy
        let w:context.force_fix_strategy = ''
    endif

    if w:context.top_line != top_line
        let w:context.top_line = top_line
        let w:context.needs_update = 1
    endif

    if w:context.bottom_line != bottom_line
        let w:context.bottom_line = bottom_line
    endif

    if w:context.cursor_line != cursor_line
        let w:context.cursor_line = cursor_line
        " let w:context.needs_move = 1
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
endfunction

function! context#util#update_line_state() abort
    let w:context.top_line    = line('w0')
    let w:context.bottom_line = line('w$')
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
