let s:nil_line = context#line#make(0, 0, 0, '')

" TODO! typing H often beeps, look into that

" NOTE: indents is being used for the ellipsis line which is shown if the
" max_height would be exceeded
let s:empty_context = {
            \ 'display_lines':     [],
            \ 'highlights':        [],
            \ 'indents':           [],
            \ 'line_numbers':      [],
            \ 'line_count':        0,
            \ 'line_count_indent': 0,
            \ 'height':            0,
            \ 'join_parts':        0,
            \ 'top_line':          s:nil_line,
            \ 'bottom_line':       s:nil_line,
            \ }

" collect all context lines
function! context#context#get(base_line) abort
    call context#util#echof('context#context#get', a:base_line.number)

    if !exists('b:context')
                \ || b:context.changedtick != b:changedtick
                \ || b:context.sign_width  != w:context.sign_width
        let b:context = {
                    \ 'changedtick': b:changedtick,
                    \ 'sign_width':  w:context.sign_width,
                    \ 'contexts':    {},
                    \ }
    endif

    " check cache
    let context = get(b:context.contexts, a:base_line.number, {})
    if context != {} " cache hit
        call context#util#echof('found cached')

        " update relative numbers
        let width = w:context.number_width
        if &relativenumber && width > 0
            for i in range(0, len(context.line_numbers)-1)
                let line_number = context.line_numbers[i]
                if line_number == 0
                    continue
                endif
                let n = w:context.cursor_line - line_number
                let part = repeat(' ', w:context.sign_width + width-len(n)-1) . n
                let context.display_lines[i] = part . context.display_lines[i][len(part) :]
            endfor
        endif
        return context
    endif

    let context_map = {}

    " recursive call
    let context_line = s:get_context_line(a:base_line)
    if context_line.number == 0
        " there's no context for a:base_line
        let b:context.contexts[a:base_line.number] = s:empty_context " add to cache
        return s:empty_context
    endif

    let parent_context = context#context#get(context_line)
    let context = deepcopy(parent_context)
    let context.bottom_line = context_line
    if context.line_count == 0
        let context.top_line = context_line
    endif

    if context#line#should_join(context_line.text)
                \ && context.line_count > 0
                \ && context_line.level == parent_context.bottom_line.level

        " append to previous line
        let context.join_parts += 1
        if context.join_parts == g:context.max_join_parts + 1
            let line = context.display_lines[context.line_count-1]
            let col = strlen(line)

            let part = ' ' . g:context.ellipsis
            let width = len(part)
            let line .= part
            call add(context.highlights[context.line_count-1], ['Comment', col, width])
            let col += width

            let context.display_lines[context.line_count-1] = line

        elseif context.join_parts <= g:context.max_join_parts
            let line = context.display_lines[context.line_count-1]
            let col = strlen(line)

            if context_line.number > parent_context.bottom_line.number + 1
                let part = ' ' . g:context.ellipsis
                let width = len(part)
                let line .= part
                call add(context.highlights[context.line_count-1], ['Comment', col, width])
                let col += width
            endif

            let [text, highlights] = context#line#display([context_line], col+1)
            let part = ' ' . text
            let col = len(part)
            let line .= part
            call extend(context.highlights[context.line_count-1], highlights)

            let context.display_lines[context.line_count-1] = line
        endif

    else
        " add new line
        let [text, highlights] = context#line#display([context_line], 0)
        call insert(context.display_lines, text, parent_context.line_count)
        call insert(context.highlights, highlights, parent_context.line_count)
        call insert(context.indents, context_line.indent, parent_context.line_count)
        call insert(context.line_numbers, context_line.number, parent_context.line_count)
        let context.line_count += 1
        let context.height += 1
        let context.join_parts = 1

        if context_line.level != parent_context.bottom_line.level
            let context.line_count_indent = 1
        else
            let context.line_count_indent += 1

            if context.line_count_indent > g:context.max_per_level
                let index = context.line_count - g:context.max_per_level/2 - 2

                let ellipsis_line = context#line#make_highlight(0,
                            \ g:context.char_ellipsis,
                            \ context_line.level,
                            \ context_line.indent,
                            \ g:context.ellipsis,
                            \ 'Comment')

                let [text, highlights] = context#line#display([ellipsis_line], 0)
                let context.display_lines[index] = text
                let context.highlights[index] = highlights
                let context.indents[index] = ellipsis_line.indent
                let context.line_numbers[index] = ellipsis_line.number

                call remove(context.display_lines, index+1)
                call remove(context.highlights, index+1)
                call remove(context.indents, index+1)
                call remove(context.line_numbers, index+1)
                let context.line_count -= 1
                let context.line_count_indent -= 1
                let context.height -= 1
            endif
        endif

        let max_height = g:context.max_height
        if context.line_count > max_height
            let index = max_height/2

            let indent  = context.indents[index]
            let indent2 = context.indents[index+2]
            let ellipsis = repeat(g:context.char_ellipsis, max([indent2 - indent, 3]))
            let ellipsis_line = context#line#make_highlight(0, g:context.char_ellipsis, 0, indent, ellipsis, 'Comment')

            let [text, highlights] = context#line#display([ellipsis_line], 0)
            let context.display_lines[index] = text
            let context.highlights[index] = highlights
            let context.indents[index] = ellipsis_line.indent
            let context.line_numbers[index] = ellipsis_line.number

            call remove(context.display_lines, index+1)
            call remove(context.highlights, index+1)
            call remove(context.indents, index+1)
            call remove(context.line_numbers, index+1)
            let context.line_count -= 1
            let context.height -= 1
        endif
    endif

    if g:context.show_border
        let border_line = s:get_border_line(a:base_line.number)
        let [text, highlights] = context#line#display(border_line, 0)

        if parent_context.line_count == 0
            call add(context.display_lines, text)
            call add(context.highlights, highlights)
            let context.height += 1
        else
            let context.display_lines[-1] = text
            let context.highlights[-1] = highlights
        endif
    endif

    let b:context.contexts[a:base_line.number] = context " add to cache
    return context
endfunction

function! s:get_context_line(line) abort
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
            let current_line -= 1
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

let s:context_buffer_name = '<context.vim>'

function! s:get_border_line(base_line) abort
    let [level, indent] = g:context.Border_indent(a:base_line)

    let line_len = w:context.size_w - w:context.sign_width - w:context.number_width - indent - 1
    let border_char = g:context.char_border
    if !g:context.show_tag
        let border_text = repeat(g:context.char_border, line_len) . ' '
        return [context#line#make_highlight(0, border_char, level, indent, border_text, g:context.highlight_border)]
    endif

    let line_len -= len(s:context_buffer_name) + 1
    let border_text = repeat(g:context.char_border, line_len)
    let tag_text = ' ' . s:context_buffer_name
    return [
                \ context#line#make_highlight(0, border_char, level, indent, border_text, g:context.highlight_border),
                \ context#line#make_highlight(0, border_char, level, indent, tag_text,    g:context.highlight_tag)
                \ ]
endfunction
