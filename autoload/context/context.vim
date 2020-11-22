let s:nil_line = context#line#make(0, 0, 0, '')

let s:empty_context = {
            \ 'display_lines': [],
            \ 'highlights':    [],
            \ 'line_count':    0,
            \ 'height':        0,
            \ }

" collect all context lines
" TODO: update/remove this comment
" returns [context, line_count]
" context has this structure:
" [
"   [ // lines in this list have the same indentation (used for max height per indent)
"     [ // line in this list are allowed to be joined
"       {line},
"       {line}
"     ]
"   ]
" ]
function! context#context#get(base_line) abort
    call context#util#echof('context#context#get', a:base_line.number)

    " check cache
    let context = get(w:context.contexts, a:base_line.number, {})
    if context != {} " cache hit
        call context#util#echof('found cached')
        return context
    endif

    let context_map = {}

    if !exists('b:context') || b:context.tick != b:changedtick
        " skips is a dictionary that maps a line to its next context line so
        " it allows us to skip large portions of the buffer instead of always
        " having to scan through all of it
        " TODO: remove skips cache? otherwise consider caching the full line,
        " not only the line number (as dict value)
        let b:context = {
                    \ 'tick':  b:changedtick,
                    \ 'skips': {},
                    \ }
    endif

    " recursive call
    let context_line = s:get_context_line(a:base_line)
    let b:context.skips[a:base_line.number] = context_line.number " cache this lookup

    if context_line.number == 0
        " there's no context for a:base_line
        " TODO: cache this too (empty context for this a:base_line)
        " TODO: later, add wrapper function to take care of caching contexts?
        return s:empty_context
    endif
    let parent_context = context#context#get(context_line)
    let context = deepcopy(parent_context)

    " TODO: handle skipping lines within this function too, instead of on the
    " caller side?

    if context#line#should_join(context_line.text) && context.line_count > 0
        " append to previous line
        let line = context.display_lines[context.line_count-1]
        let col = strlen(line)

        " TODO!: only add ellipsis if there are line in between
        " see context#util#limit_join_parts()
        let part = ' ' . g:context.ellipsis
        let width = len(part)
        let line .= part
        call add(context.highlights[context.line_count-1], ['Comment', col, width])
        let col += width

        " TODO: add ellipsis5 as middle marker if max_join_parts is reached/exceeded

        let [text, highlights] = context#line#display(0, [context_line], col+1)
        let part = ' ' . text
        let col = len(part)
        let line .= part
        call extend(context.highlights[context.line_count-1], highlights)

        let context.display_lines[context.line_count-1] = line
        " TODO: it seems that the LineNr highlight is duplicated, check and fix
        " call context#util#echof('context.highlights', context.highlights)

    else
        " add new line
        let [text, highlights] = context#line#display(1, [context_line], 0)
        call insert(context.display_lines, text, parent_context.line_count)
        call insert(context.highlights, highlights, parent_context.line_count)
        let context.line_count += 1
        let context.height += 1
    endif

    if g:context.show_border
        let [level, indent] = g:context.Border_indent(a:base_line.number)
        let border_line = context#util#get_border_line(level, indent)
        let [text, highlights] = context#line#display(1, border_line, 0)
        if parent_context.line_count == 0
            call add(context.display_lines, text)
            call add(context.highlights, highlights)
            let context.height += 1
        else
            let context.display_lines[-1] = text
            let context.highlights[-1] = highlights
        endif
    endif

    let w:context.contexts[a:base_line.number] = context " add to cache
    return context


    " TODO: delete everything below

    let context_map = {}

    while 1
        let context_line = s:get_context_line(base_line)
        let b:context.skips[base_line.number] = context_line.number " cache this lookup

        if context_line.number == 0
            break
        endif

        let level = context_line.level
        if !has_key(context_map, level)
            let context_map[level] = []
        endif

        call insert(context_map[level], context_line, 0)

        " for next iteration
        let base_line = context_line
    endwhile

    let context_list = []
    let line_count = 0
    " join, limit and get context lines
    " NOTE: at this stage lines changes from list to list of lists
    for level in sort(keys(context_map), 'N')
        " NOTE: s:join switches from list to list of lists, grouping lines
        " that are allowed to be joined on the caller side
        let joined = s:join(context_map[level])
        call add(context_list, joined)
        if len(joined) > g:context.max_per_level
            let line_count += g:context.max_per_level
        else
            let line_count += len(joined)
        endif
    endfor

    let [lines, border_line_number] = context#util#filter(context_list, line_count, 1)

    let display_lines = []
    let hls = [] " list of lists, one per context line
    for line in lines
        let [text, highlights] = context#line#display(line)
        call add(display_lines, text)
        call add(hls, highlights)
    endfor

    if g:context.show_border
        let [level, indent] = g:context.Border_indent(border_line_number)
        let border_line = context#util#get_border_line(level, indent)
        let [text, highlights] = context#line#display(border_line)
        call add(display_lines, text)
        call add(hls, highlights)
    endif

    " TODO: do we really need line_count, or can we use a different field
    " instead? or do we need line_count AND height?
    let context = {
                \ 'display_lines': display_lines,
                \ 'highlights':    hls,
                \ 'line_count':    len(lines),
                \ 'height':        len(display_lines),
                \ }
    let w:context.contexts[a:base_line.number] = context " add to cache
    return context
endfunction

function! s:get_context_line(line) abort
    " check if we have a skip available from the base line
    let skipped = get(b:context.skips, a:line.number, -1)
    if skipped != -1
        " call context#util#echof('  skipped', a:line.number, '->', skipped)
        let [level, indent] = g:context.Indent(skipped)
        return context#line#make_trimmed(skipped, level, indent, getline(skipped))
    endif

    " if line starts with closing brace or similar: jump to matching
    " opening one and add it to context. also for other prefixes to show
    " the if which belongs to an else etc.
    if context#line#should_extend(a:line.text)
        let max_level = a:line.level " allow same level
    else
        let max_level = a:line.level - 1 " must be strictly less
    endif

    if max_level < 0
        return s:nil_line
    endif

    " search for line with matching level
    let current_line = a:line.number - 1
    while 1
        if current_line <= 0
            " nothing found
            return s:nil_line
        endif

        let [level, indent] = g:context.Indent(current_line)
        if level > max_level
            " use skip if we have, next line otherwise
            let skipped = get(b:context.skips, current_line, current_line-1)
            let current_line = skipped
            continue
        endif

        let text = getline(current_line)
        if context#line#should_skip(text)
            let current_line -= 1
            continue
        endif

        return context#line#make_trimmed(current_line, level, indent, text)
    endwhile
endfunction

function! s:join(lines) abort
    " call context#util#echof('> join', len(a:lines))
    let joined = [a:lines[:0]] " start with first line
    for line in a:lines[1:]
        if context#line#should_join(line.text)
            " add to previous group
            call add(joined[-1], line)
        else
            " create new group
            call add(joined, [line])
        endif
    endfor

    return joined
endfunction
