function! context#line#make(number, indent, text) abort
    return context#line#make_highlight(a:number, '', a:indent, a:text, '')
endfunction

function! context#line#make_trimmed(number, indent, text) abort
    let trimmed_text = context#line#trim(a:text)
    return {
                \ 'number':         a:number,
                \ 'number_char':    '',
                \ 'indent':         a:indent,
                \ 'indent_chars':   len(a:text) - len(trimmed_text),
                \ 'text':           trimmed_text,
                \ 'highlight':      '',
                \ }
endfunction

function! context#line#make_highlight(number, number_char, indent, text, highlight) abort
    return {
                \ 'number':         a:number,
                \ 'number_char':    a:number_char,
                \ 'indent':         a:indent,
                \ 'indent_chars':   a:indent,
                \ 'text':           a:text,
                \ 'highlight':      a:highlight,
                \ }
endfunction

let s:nil_line = context#line#make(0, 0, '')

" find line downwards (from given line) which isn't empty
function! context#line#get_base_line(line) abort
    let current_line = a:line
    while 1
        let indent = g:context.Indent(current_line)
        if indent < 0 " invalid line
            return s:nil_line
        endif

        let text = getline(current_line)
        if context#line#should_skip(text)
            let current_line += 1
            continue
        endif

        return context#line#make(current_line, indent, text)
    endwhile
endfunction

function! context#line#join(batch) abort
    return s:join(a:batch)

    " TODO: clean up/inline
    let line = a:batch[0]
    let text = s:join(a:batch)

    " TODO: where should this debug output go now?
    " let n = &columns - 30 - strchars(context#line#trim(text)) - line.indent
    " let text = printf('%s%s // %2d n:%5d i:%2d', text, repeat(' ', n), len(a:batch), line.number, line.indent)

    return context#line#make(line.number, line.indent, text)
endfunction

" TODO: rename? doesn't really join now, but just enforce max_join_parts
function! s:join(lines) abort
    " call context#util#echof('> join', len(a:lines))
    if len(a:lines) == 1
        return a:lines
    endif

    let max = g:context.max_join_parts

    if max == 1
        return [a:lines[0]]
    elseif max == 2
        " TODO: add vars for ellipsis lines?
        let text = ' ' . g:context.ellipsis
        return [a:lines[0], context#line#make_highlight(0, '', 0, text, 'Comment')]
    endif

    if len(a:lines) > max " too many parts
        let text = ' ' . g:context.ellipsis5 . ' '
        call remove(a:lines, (max+1)/2, -max/2-1)
        call insert(a:lines, context#line#make_highlight(0, '', 0, text, 'Comment'), (max+1)/2) " middle marker
    endif

    " insert ellipses where there are gaps between the parts
    let i = 0
    while i < len(a:lines) - 1
        let [n1, n2] = [a:lines[i].number, a:lines[i+1].number]
        if n1 > 0 && n2 > 0
            " show ellipsis if line i+1 is not directly below line i
            let text = n2 > n1 + 1 ? ' ' . g:context.ellipsis . ' ' : ' '
            call insert(a:lines, context#line#make_highlight(0, '', 0, text, 'Comment'), i+1)
        endif
        let i += 1
    endwhile

    return a:lines
endfunction

" returns list of [line, [highlights]]
" where each highlight is [hl, col, width]
function! context#line#display(join_parts) abort
    let col = 1 " TODO: can we infer this from len(text) or something?
    let text = ''
    let highlights = []
    let part0 = a:join_parts[0]

    " TODO: remove and use the below instead. we then probably need to call
    " #display again from context#popup#layout with injected winid. but test
    " this first, make sure this is actually needed (probably is), have
    " multiple windows, some with sign/number columns others without and then
    " trigger layout or similar
    let c = w:context

    " let c = getwinvar(a:winid, 'context', {})
    " if c == {}
    "     " TODO: can this happen? do we need this check?
    "     return [text, highlights]
    " endif

    " NOTE: we use non breaking spaces for padding in order to not show
    " 'listchars' in the sign and number columns

    " sign column
    let width = c.sign_width
    if width > 0
        let part = repeat(' ', width)
        let width = len(part)
        call add(highlights, ['SignColumn', col, width])
        let text .= part
        let col += width
    endif

    " number column
    let width = c.number_width
    if width > 0
        if part0.number_char != ''
            " NOTE: we use a non breaking space here because number_char can
            " be border_char
            let part = repeat(part0.number_char, width-1) . ' '
        else
            if &relativenumber
                let n = c.cursor_line - part0.number
            elseif &number
                let n = part0.number
            endif
            " let part = printf('%*d ', width - 1, n)
            let part = repeat(' ', width-len(n)-1) . n . ' '
        endif

        let width = len(part)
        call add(highlights, ['LineNr', col, width])
        let text .= part
        let col += width
    endif

    " indent
    " TODO: use `space` to fake tab listchars?
    " let [_, space, text; _] = matchlist(part0.text, '\v^(\s*)(.*)$')
    let part = repeat(' ', part0.indent)
    let text .= part
    let col += len(part)

    " text
    let prev_hl = ''
    for j in range(0, len(a:join_parts)-1)
        let join_part = a:join_parts[j]
        let text .= join_part.text

        " " highlight individual join parts for debugging
        " let width = len(join_part.text)
        " let hl = j % 2 == 0 ? 'Search' : 'IncSearch'
        " call add(highlights, [hl, col, width])
        " let col += width

        let count = 0

        if join_part.highlight != ''
            let count = len(join_part.text)
            call add(highlights, [join_part.highlight, col, count])
            let col += count
            let count = 1
            continue
        endif

        for line_col in range(1+join_part.indent_chars, join_part.indent_chars + len(join_part.text)+1) " TODO: only up to windowwidth
            let hlgroup = synIDattr(synIDtrans(synID(join_part.number, line_col, 1)), 'name')

            if hlgroup == prev_hl " TODO: add col < end condition?
                let count += 1
                continue
            endif

            if prev_hl != ''
                call add(highlights, [prev_hl, col, count])
            endif

            let prev_hl = hlgroup
            let col += count
            let count = 1
        endfor
        let col += count-1
    endfor

    return [text, highlights]
endfunction

" TODO: make this an s: function? only used in here
function! context#line#trim(string) abort
    return substitute(a:string, '^\s*', '', '')
endfunction

function! context#line#should_extend(line) abort
    return a:line =~ g:context.regex_extend
endfunction

function! context#line#should_skip(line) abort
    return a:line =~ g:context.regex_skip
endfunction

function! context#line#should_join(line) abort
    if g:context.max_join_parts < 1
        return 0
    endif

    return a:line =~ g:context.regex_join
endfunction
