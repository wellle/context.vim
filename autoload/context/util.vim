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
    let n = w:context.context.height + v:count1
    if v:count > 0
        return repeat("\<Del>", len(v:count)) . n . 'H'
    endif
    return n . 'H'
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

    " bench_limit is a crude way of terminating our benchmark
    if cursor_line == g:context.bench_limit
        quit!
    endif

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
        silent! unlet b:context " invalidate cache
    endif

    " NOTE: we need to save and restore the cursor position because setting
    " 'virtualedit' resets curswant #84
    let cursor = getcurpos()
    let old = [&virtualedit, &conceallevel]
    let [&virtualedit, &conceallevel] = ['all', 0]
    let sign_width = wincol() - virtcol('.') - number_width
    let [&virtualedit, &conceallevel] = old
    call setpos('.', cursor)

    " NOTE: sign_width can be negative if the cursor is on the wrapped part of
    " a wrapped line. in that case ignore the value
    if sign_width >= 0 && w:context.sign_width != sign_width
        " call context#util#echof('sign width changed', w:context.sign_width, sign_width)
        let w:context.sign_width = sign_width
        let w:context.needs_update = 1
        silent! unlet b:context " invalidate cache
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

    let [height, width] = [winheight(a:winid), winwidth(a:winid)]
    if c.size_w != width
        let [c.size_h, c.size_w] = [height, width]
        " because we now cache the border line too, we need to update the
        " context in order to redraw the border line with the new length
        let c.needs_update = 1
        silent! unlet b:context " invalidate cache
    elseif c.size_h != height
        let [c.size_h, c.size_w] = [height, width]
        " on height change we only need to fix the layout
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

function! s:set_fix_strategy(context, message, strategy) abort
    " call context#util#echof(printf('set_fix_strategy(%s)  %s -> %s', a:context, a:message, a:strategy))
    let w:context.fix_strategy = a:strategy
    let w:context.needs_update = 1
endfunction
