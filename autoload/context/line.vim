function! context#line#make(number, indent, text) abort
    return {
                \ 'number': a:number,
                \ 'indent': a:indent,
                \ 'text':   a:text,
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

        let line = getline(current_line)
        if context#line#should_skip(line)
            let current_line += 1
            continue
        endif

        return context#line#make(current_line, indent, line)
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
        return [a:lines[0], context#line#make(0, 0, g:context.ellipsis)]
    endif

    if len(a:lines) > max " too many parts
        call remove(a:lines, (max+1)/2, -max/2-1)
        call insert(a:lines, context#line#make(0, 0, g:context.ellipsis5), (max+1)/2) " middle marker
    endif

    " insert ellipses where there are gaps between the parts
    let i = 0
    while i < len(a:lines) - 1
        let [n1, n2] = [a:lines[i].number, a:lines[i+1].number]
        if n1 > 0 && n2 > 0 && n2 > n1 + 1
            " line i+1 is not directly below line i, so add a marker
            call insert(a:lines, context#line#make(0, 0, g:context.ellipsis), i+1)
        endif
        let i += 1
    endwhile

    return a:lines
endfunction

function! context#line#text(i, lines) abort
    " TODO: do the same in border line
    " TODO: for border line use number of lines hidden below bottom context
    " line and topmost visible line? maybe with different highlight group?

    " sign column
    let text = repeat(' ', w:context.sign_width)

    " number column
    " TODO: remove special handling for 0 again
    if a:lines[0].number == 0
        let text .= repeat(' ', w:context.number_width)
    elseif w:context.number_width > 0
        if &relativenumber
            let n = w:context.cursor_line - a:lines[0].number
        elseif &number
            let n = a:lines[0].number
        endif
        let text .= printf('%*d ', w:context.number_width - 1, n)
    endif

    " indent
    " TODO: use `space` to fake tab listchars?
    " let [_, space, text; _] = matchlist(a:lines[0].text, '\v^(\s*)(.*)$')
    let text .= repeat(' ', a:lines[0].indent)

    " text
    for i in range(0, len(a:lines) - 1)
        if i > 0
            let text .= ' '
        endif
        let text .=  context#line#trim(a:lines[i].text)
    endfor

    return text
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
