function! context#util#active() abort
    return 1
                \ && w:context.enabled
                \ && !get(g:context.filetype_blacklist, &filetype)
endfunction

function! context#util#map(arg) abort
    if mode(1) == 'niI' " i^o
        return a:arg
    endif
    return a:arg . ":call context#update('" . a:arg . "')\<CR>"
endfunction

function! context#util#map_H() abort
    if mode(1) == 'niI' " i^o
        return 'H'
    endif
    " TODO: handle scrolloff
    let n = len(w:context.lines) + v:count1
    return "\<Esc>". n . 'H'
endfunction

function! context#util#map_zt() abort
    if mode(1) == 'niI' " i^o
        return 'zt'
    endif
    let w:context.force_fix_strategy = 'scroll'
    return "zt:call context#update('zt')\<CR>"
endfunction

" TODO: there's an issue with fzf popup. when switching from one buffer to a
" new buffer in some cases the context popup doesn't update. probably need to
" set w:context.needs_update in some additional case below

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

    if &number
        " depends on total number of lines
        let number_width = max([&numberwidth, float2nr(ceil(log10(line('$') + 1))) + 1])
    elseif &relativenumber
        " depends on number of visible lines
        let number_width = max([&numberwidth, float2nr(ceil(log10(&lines - 1))) + 1])
    else
        let number_width = 0
    endif
    if w:context.number_width != number_width
        call context#util#echof('number width changed', w:context.number_width, number_width)
        let w:context.number_width = number_width
        let w:context.needs_update = 1
    endif

    let old = [&virtualedit, &conceallevel]
    let [&virtualedit, &conceallevel] = ['all', 0]
    let sign_width = wincol() - virtcol('.') - number_width
    let [&virtualedit, &conceallevel] = old
    " NOTE: sign_width can be negative if the cursor is on the wrapped part of
    " a wrapped line. in that case ignore the value
    if sign_width >= 0 && w:context.sign_width != sign_width
        call context#util#echof('sign width changed', w:context.sign_width, sign_width)
        let w:context.sign_width = sign_width
        let w:context.needs_update = 1
    endif

    " TODO: remove padding, use sign_width and number_width exclusively instead
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

" this is a pretty weird function
" it has been extracted to reduce duplication between popup and preview code
" what it does: it goes through all lines of the given full context and
" filters which lines should be visible in the filtered context.
" this is to avoid displaying lines in the context which are already visible
" on screen
" additionally this function applies the per indent and the total limits for
" lines displayed within a context
" finally it maps the lines and returns a list of the context lines which are
" to be displayed together with the line_number which should be used for the
" indentation of the border line/status line
function! context#util#filter(context, line_number, consider_height) abort
    let line_number = a:line_number
    let max_height = g:context.max_height
    let max_height_per_indent = g:context.max_per_indent

    let height = 0
    let done = 0
    let lines = []
    for per_indent in a:context
        if done
            break
        endif

        let inner_lines = []
        for join_batch in per_indent
            if done
                break
            endif

            if join_batch[0].number >= w:context.top_line + height
                let line_number = join_batch[0].number
                let done = 1
                break
            endif

            if a:consider_height
                if height == 0 && g:context.show_border
                    let height += 2 " adding border line
                elseif height < max_height && len(inner_lines) < max_height_per_indent
                    let height += 1
                endif
            endif

            for i in range(1, len(join_batch)-1)
                if join_batch[i].number > w:context.top_line + height
                    let line_number = join_batch[i].number
                    let done = 1
                    call remove(join_batch, i, -1)
                    break " inner loop
                endif
            endfor

            let line = context#line#join(join_batch)
            call add(inner_lines, line)
        endfor

        " apply max per indent
        if len(inner_lines) <= max_height_per_indent
            call extend(lines, inner_lines)
            continue
        endif

        let diff = len(inner_lines) - max_height_per_indent

        let indent = inner_lines[0].indent
        let limited = inner_lines[: max_height_per_indent/2-1]
        let ellipsis_line = context#line#make(0, indent, repeat(' ', indent) . g:context.ellipsis)
        call add(limited, ellipsis_line)
        call extend(limited, inner_lines[-(max_height_per_indent-1)/2 :])

        call extend(lines, limited)
    endfor

    if len(lines) == 0
        return [[], 0]
    endif

    " apply total limit
    if len(lines) > max_height
        let indent1 = lines[max_height/2].indent
        let indent2 = lines[-(max_height-1)/2].indent
        let ellipsis = repeat(g:context.char_ellipsis, max([indent2 - indent1, 3]))
        let ellipsis_line = context#line#make(0, indent1, repeat(' ', indent1) . ellipsis)
        call remove(lines, max_height/2, -(max_height+1)/2)
        call insert(lines, ellipsis_line, max_height/2)
    endif

    call map(lines, function('context#line#text'))
    return [lines, line_number]
endfunction

function! context#util#show_cursor() abort
    " compare height of context to cursor line on screen
    let n = len(w:context.lines) - (w:context.cursor_line - w:context.top_line)
    if n <= 0
        " if cursor is low enough, nothing to do
        return
    end

    " otherwise we have to either move or scroll the cursor accordingly
    " call context#util#echof('show_cursor', w:context.fix_strategy, n)
    let key = (w:context.fix_strategy == 'move') ? 'j' : "\<C-Y>"
    execute 'normal! ' . n . key
    call context#util#update_line_state()
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

function! s:set_fix_strategy(context, message, strategy) abort
    " call context#util#echof(printf('set_fix_strategy(%s)  %s -> %s', a:context, a:message, a:strategy))
    let w:context.fix_strategy = a:strategy
    let w:context.needs_update = 1
endfunction
