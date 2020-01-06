" TODO: check what's left here and decide what should go where
" also look at util again, maybe split
" TODO: don't hide cursor, hide (partially) context instead, hint that it's
" partial?
" TODO: reorder functions and split out into autoload dirs

" TODO: these used to be s:, are now g:, need update/move?
" consts
let g:context_buffer_name = '<context.vim>'

" cached
let g:context_ellipsis  = repeat(g:context_ellipsis_char, 3)
let g:context_ellipsis5 = repeat(g:context_ellipsis_char, 5)
" TODO: use make_line later?
let s:nil_line = {'number': 0, 'indent': 0, 'text': ''}

" state
" NOTE: there's more state in window local w: variables
let s:activated     = 0
let s:ignore_update = 0


" call this on VimEnter to activate the plugin
function! context#activate() abort
    " for some reason there seems to be a race when we try to show context of
    " one buffer before another one gets opened in startup
    " to avoid that we wait for startup to be finished
    let s:activated = 1
    call context#update(0, 'activate')
endfunction

function! context#enable() abort
    let g:context_enabled = 1
    call context#update(1, 'enable')
endfunction

function! context#disable() abort
    let g:context_enabled = 0

    " TODO: extract one general function, similar in other places
    " TODO: also how can we avoid the explicit presenter checks?
    call context#popup#clear()
    if g:context_presenter == 'preview'
        call context#preview#close()
    endif
endfunction

function! context#toggle() abort
    if g:context_enabled
        call context#disable()
    else
        call context#enable()
    endif
endfunction


function! context#update(force_resize, source) abort
    if 0
                \ || !g:context_enabled
                \ || !s:activated
                \ || s:ignore_update
                \ || &previewwindow
                \ || mode() != 'n'
        return
    endif

    let s:ignore_update = 1

    let winid = win_getid()

    let w:context_needs_update = a:force_resize
    let w:context_needs_layout = a:force_resize
    call context#util#update_state()
    call context#util#update_window_state(winid)

    if w:context_needs_update || w:context_needs_layout
        call context#util#echof()
    endif

    if w:context_needs_update
        call s:update_context(winid, 1, a:force_resize, a:source)
    endif

    if w:context_needs_layout && g:context_presenter != 'preview'
        call context#popup#update_layout()
    endif

    let w:context_needs_update = 0
    let w:context_needs_layout = 0

    let s:ignore_update = 0
endfunction

function! context#clear_cache() abort
    call context#update(0, 'clear_cache')
endfunction

function! context#cache_stats() abort
    let skips = len(b:context_skips)
    let cost  = b:context_cost
    let total = b:context_cost + b:context_saved
    echom printf('cache: %d skips, %d / %d (%.1f%%)', skips, cost, total, 100.0 * cost / total)
endfunction

" NOTE: winid is injected, but will always be current window
" TODO: remove allow_resize, force_resize?
function! s:update_context(winid, allow_resize, force_resize, source) abort
    call context#util#echof('> update_context', a:source, a:winid, w:context_top_line)
    call context#util#log_indent(2)

    if g:context_presenter == 'preview'
        let lines = context#preview#get_context(a:allow_resize, a:force_resize)
    else
        let lines = context#popup#get_context()
    endif

    " TODO: remove
    if len(lines) > 0
        let lines[0] .= ' // winid ' . a:winid
    endif

    if g:context_presenter == 'preview'
        call context#preview#show(lines)
    else
        call context#popup#show(a:winid, lines)
    endif

    if g:context_presenter == 'preview'
        " call again until it stabilizes
        call context#util#update_state()
        if w:context_needs_update
            let w:context_needs_update = 0
            call s:update_context(a:winid, 0, 0, 'recurse')
        endif
    endif

    call context#util#log_indent(-2)
endfunction

" TODO: move to #util?
" collect all context lines
function! context#get_context(line) abort
    let base_line = a:line
    if base_line.number == 0
        return []
    endif

    let context = {}

    if get(b:, 'context_tick') != b:changedtick
        let b:context_tick  = b:changedtick
        " this dictionary maps a line to its next context line
        " so it allows us to skip large portions of the buffer instead of always
        " having to scan through all of it
        let b:context_skips = {}
        let b:context_cost  = 0
        let b:context_saved = 0
    endif

    while 1
        let context_line = s:get_context_line(base_line)
        let b:context_skips[base_line.number] = context_line.number " cache this lookup

        if context_line.number == 0
            break
        endif

        let indent = context_line.indent
        if !has_key(context, indent)
            let context[indent] = []
        endif

        call insert(context[indent], context_line, 0)

        " for next iteration
        let base_line = context_line
    endwhile

    " join, limit and get context lines
    let lines = []
    for indent in sort(keys(context), 'N')
        let context[indent] = s:join(context[indent])
        let context[indent] = s:limit(context[indent], indent)
        call extend(lines, context[indent])
    endfor

    " limit total context
    let max = g:context_max_height
    if len(lines) > max
        let indent1 = lines[max/2].indent
        let indent2 = lines[-(max-1)/2].indent
        let ellipsis = repeat(g:context_ellipsis_char, max([indent2 - indent1, 3]))
        let ellipsis_line = context#util#make_line(0, indent1, repeat(' ', indent1) . ellipsis)
        call remove(lines, max/2, -(max+1)/2)
        call insert(lines, ellipsis_line, max/2)
    endif

    return lines
endfunction

function! s:get_context_line(line) abort
    " check if we have a skip available from the base line
    let skipped = get(b:context_skips, a:line.number, -1)
    if skipped != -1
        let b:context_saved += a:line.number-1 - skipped
        " call context#util#echof('  skipped', a:line.number, '->', skipped)
        return context#util#make_line(skipped, indent(skipped), getline(skipped))
    endif

    " if line starts with closing brace or similar: jump to matching
    " opening one and add it to context. also for other prefixes to show
    " the if which belongs to an else etc.
    if context#util#extend_line(a:line.text)
        let max_indent = a:line.indent " allow same indent
    else
        let max_indent = a:line.indent - 1 " must be strictly less
    endif

    if max_indent < 0
        return s:nil_line
    endif

    " search for line with matching indent
    let current_line = a:line.number - 1
    while 1
        if current_line <= 0
            " nothing found
            return s:nil_line
        endif

        let b:context_cost += 1

        let indent = indent(current_line)
        if indent > max_indent
            " use skip if we have, next line otherwise
            let skipped = get(b:context_skips, current_line, current_line-1)
            let b:context_saved += current_line-1 - skipped
            let current_line = skipped
            continue
        endif

        let line = getline(current_line)
        if context#util#skip_line(line)
            let current_line -= 1
            continue
        endif

        return context#util#make_line(current_line, indent, line)
    endwhile
endfunction


" utility functions

function! s:join(lines) abort
    " only works with at least 3 parts, so disable otherwise
    if g:context_max_join_parts < 3
        return a:lines
    endif

    " call context#util#echof('> join', len(a:lines))
    let pending = [] " lines which might be joined with previous
    let joined = a:lines[:0] " start with first line
    for line in a:lines[1:]
        if context#util#join_line(line.text)
            " add lines without word characters to pending list
            call add(pending, line)
            continue
        endif

        " don't join lines with word characters
        " but first join pending lines to previous output line
        let joined[-1] = s:join_pending(joined[-1], pending)
        let pending = []
        call add(joined, line)
    endfor

    " join remaining pending lines to last
    let joined[-1] = s:join_pending(joined[-1], pending)
    return joined
endfunction

function! s:join_pending(base, pending) abort
    " call context#util#echof('> join_pending', len(a:pending))
    if len(a:pending) == 0
        return a:base
    endif

    let max = g:context_max_join_parts
    if len(a:pending) > max-1
        call remove(a:pending, (max-1)/2-1, -max/2-1)
        call insert(a:pending, s:nil_line, (max-1)/2-1) " middle marker
    endif

    let joined = a:base
    for line in a:pending
        let joined.text .= ' '
        if line.number == 0
            " this is the middle marker, use long ellipsis
            let joined.text .= g:context_ellipsis5
        elseif joined.number != 0 && line.number != joined.number + 1
            " not after middle marker and there are lines in between: show ellipsis
            let joined.text .= g:context_ellipsis . ' '
        endif

        let joined.text .= context#util#trim(line.text)
        let joined.number = line.number
    endfor

    return joined
endfunction

function! s:limit(lines, indent) abort
    " call context#util#echof('> limit', a:indent, len(a:lines))

    let max = g:context_max_per_indent
    if len(a:lines) <= max
        return a:lines
    endif

    let diff = len(a:lines) - max

    let limited = a:lines[: max/2-1]
    call add(limited, context#util#make_line(0, a:indent, repeat(' ', a:indent) . g:context_ellipsis))
    call extend(limited, a:lines[-(max-1)/2 :])
    return limited
endif
endfunction
