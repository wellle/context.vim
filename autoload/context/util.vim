function! context#util#active() abort
    return 1
                \ && w:context.enabled
                \ && !get(g:context.filetype_blacklist, &filetype)
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
    " TODO: continue here. based on the numbers (what changed, does new cursor
    " line equal top line, etc.) decide whether the last motion was scroll or
    " move, then fix cursor position my move or scroll accordingly.
    " then we won't need custom mappings anymore \o/

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
        call context#util#echof('xxx 1', winid, '|', old_top_line, top_line, '|', old_cursor_line, cursor_line, '|', old_bottom_line, bottom_line)
        if old_top_line == 0
            call context#util#echof('xxx 2 new: scroll')
        elseif cursor_line_changed && top_line_changed
            if cursor_line == top_line
                if cursor_line < old_cursor_line
                    " NOTE: this is also sometimes wrong
                    " try alternating <C-F> and <C-B>
                    call context#util#echof('xxx 3 moved')
                else
                    call context#util#echof('xxx 4 scrolled')
                endif
            elseif cursor_line == bottom_line
                if cursor_line > old_cursor_line
                    " NOTE: this is also sometimes wrong
                    " try alternating <C-F> and <C-B>
                    call context#util#echof('xxx 5 moved')
                else
                    call context#util#echof('xxx 6 scrolled')
                endif
            else
                " NOTE: this sometimes has false positives when searching.
                " sometimes it shows the next match in the middle of the
                " screen, which leads to this case. so it says scrolled even
                " though it was moved
                " TODO: we could try to catch that by comparing some diffs.
                " like cursor_diff != top_diff
                call context#util#echof('xxx 7 scrolled')
            endif
        elseif !cursor_line_changed && top_line_changed
            call context#util#echof('xxx 8 scrolled')
        elseif !cursor_line_changed && top_diff != bottom_diff
            " TODO: avoid this case, happens when scrolling too with wrap
            call context#util#echof('xxx 9 resized: scroll')
        elseif !top_line_changed && cursor_line_changed
            call context#util#echof('xxx 10 moved')
        else
            " TODO: is this a possible case still
            call context#util#echof('xxx 11 TODO')
        endif
        " TODO: are there any more cases missing?
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
        let w:context.needs_move = 1
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
