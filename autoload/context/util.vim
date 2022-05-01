let s:context_buffer_name = '<context.vim>'

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
    if g:context.presenter == 'preview'
        " nothing needed for preview
        return 'H'
    endif
    " TODO: handle scrolloff
    let n = len(w:context.lines) + g:context.show_border + v:count1
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
        " call context#util#echof('number width changed', w:context.number_width, number_width)
        let w:context.number_width = number_width
        let w:context.needs_update = 1
    endif

    " NOTE: we need to save and restore the cursor position because setting
    " 'virtualedit' resets curswant #84
    let cursor = getcurpos()
    let old = [&virtualedit, &conceallevel]
    let [&virtualedit, &conceallevel] = ['all', 0]
    let sign_width = wincol() - virtcol('.') - number_width
    let [&virtualedit, &conceallevel] = old
    if match("\<C-v>", mode()) == -1
        " Don't set cursor in visual block mode because that breaks appending, see #114
        call setpos('.', cursor)
    endif

    " NOTE: sign_width can be negative if the cursor is on the wrapped part of
    " a wrapped line. in that case ignore the value
    if sign_width >= 0 && w:context.sign_width != sign_width
        " call context#util#echof('sign width changed', w:context.sign_width, sign_width)
        let w:context.sign_width = sign_width
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

function! context#util#get_border_line(lines, level, indent, winid) abort
    let c = getwinvar(a:winid, 'context')

    " NOTE: we use a non breaking space after the border chars because there
    " can be some display issues in the Kitty terminal with a normal space

    let line_len = c.size_w - c.sign_width - c.number_width - a:indent - 1
    let border_char = g:context.char_border
    if !g:context.show_tag
        let border_text = repeat(g:context.char_border, line_len) . ' '
        return [context#line#make_highlight(0, border_char, a:level, a:indent, border_text, g:context.highlight_border)]
    endif

    let line_len -= len(s:context_buffer_name) + 1
    let border_text = repeat(g:context.char_border, line_len)
    let tag_text = ' ' . s:context_buffer_name
    return [
                \ context#line#make_highlight(0, border_char, a:level, a:indent, border_text, g:context.highlight_border),
                \ context#line#make_highlight(0, border_char, a:level, a:indent, tag_text,    g:context.highlight_tag)
                \ ]
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
    let c = g:context
    let line_number    = a:line_number
    let show_border    = c.show_border
    let max_height     = c.max_height
    let max_per_level  = c.max_per_level

    " return an empty list when the window is not tall
    " enough to display the context lines, otherwise the
    " context display overwrites the buffer's status line
    let scrolloff = &scrolloff
    if scrolloff > winheight(0) / 2
        let scrolloff = winheight(0) / 2
    endif
    let w_height_lim   = winheight(0) - scrolloff - 2
    if w_height_lim <= 0
        return [[], 0]
    endif

    let height = 0
    let done = 0
    let lines = []
    for per_level in a:context
        if done
            break
        endif

        let inner_lines = []
        for join_batch in per_level
            if done
                break
            endif

            if join_batch[0].number >= w:context.top_line + height
                let line_number = join_batch[0].number
                let done = 1
                break
            endif

            if a:consider_height
                if height == 0 && show_border
                    let height += 2 " adding border line
                elseif height < max_height + show_border && len(inner_lines) < max_per_level
                    let height += 1
                endif
            endif

            for i in range(1, len(join_batch)-1)
                if join_batch[i].number >= w:context.top_line + height
                    let line_number = join_batch[i].number
                    let done = 1
                    call remove(join_batch, i, -1)
                    break " inner loop
                endif
            endfor

            let limited_lines = context#util#limit_join_parts(join_batch)
            call add(inner_lines, limited_lines)
        endfor

        " apply max per indent
        let diff = len(inner_lines) - max_per_level
        if diff <= 0
            call extend(lines, inner_lines)
            continue
        endif


        " call context#util#echof('inner_lines', inner_lines)

        let level  = inner_lines[0][0].level
        let indent = inner_lines[0][0].indent
        let limited = inner_lines[: max_per_level/2-1]
        let ellipsis_lines = [context#line#make_highlight(0, c.char_ellipsis, level, indent, c.ellipsis, 'Comment')]
        call add(limited, ellipsis_lines)
        call extend(limited, inner_lines[-(max_per_level-1)/2 :])

        call extend(lines, limited)
    endfor

    if len(lines) == 0 || len(lines) > w_height_lim
        return [[], 0]
    endif

    " apply total limit
    let diff = len(lines) - max_height
    if diff > 0
        let level   = lines[max_height/2][0].level
        let indent  = lines[max_height/2][0].indent
        let indent2 = lines[-(max_height-1)/2][0].indent
        let ellipsis = repeat(c.char_ellipsis, max([indent2 - indent, 3]))
        let ellipsis_lines = [context#line#make_highlight(0, c.char_ellipsis, level, indent, ellipsis, 'Comment')]
        call remove(lines, max_height/2, -(max_height+1)/2)
        call insert(lines, ellipsis_lines, max_height/2)
    endif

    return [lines, line_number]
endfunction

" takes a list of join parts and checks g:context.max_join_parts
" if the limit is exceeded it's reduced with an ellipsis part
function! context#util#limit_join_parts(lines) abort
    " call context#util#echof('> join', len(a:lines))
    if len(a:lines) == 1
        return a:lines
    endif

    let max = g:context.max_join_parts

    if max == 1
        return [a:lines[0]]
    elseif max == 2
        let text = ' ' . g:context.ellipsis
        return [a:lines[0], context#line#make_highlight(0, '', 0, 0, text, 'Comment')]
    endif

    if len(a:lines) > max " too many parts
        let text = ' ' . g:context.ellipsis5 . ' '
        call remove(a:lines, (max+1)/2, -max/2-1)
        call insert(a:lines, context#line#make_highlight(0, '', 0, 0, text, 'Comment'), (max+1)/2) " middle marker
    endif

    " insert ellipses where there are gaps between the parts
    let i = 0
    while i < len(a:lines) - 1
        let [n1, n2] = [a:lines[i].number, a:lines[i+1].number]
        if n1 > 0 && n2 > 0
            " show ellipsis if line i+1 is not directly below line i
            let text = n2 > n1 + 1 ? ' ' . g:context.ellipsis . ' ' : ' '
            call insert(a:lines, context#line#make_highlight(0, '', 0, 0, text, 'Comment'), i+1)
        endif
        let i += 1
    endwhile

    return a:lines
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
