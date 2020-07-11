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
    let line = a:batch[0]
    let text = s:join(a:batch)

    let n = &columns - 30 - strchars(context#line#trim(text)) - line.indent
    let text = printf('%s%s // %2d n:%5d i:%2d', text, repeat(' ', n), len(a:batch), line.number, line.indent)

    return context#line#make(line.number, line.indent, text)
endfunction

function! s:join(lines) abort
    " call context#util#echof('> join', len(a:lines))
    let joined = a:lines[0].text
    if len(a:lines) == 1
        return joined
    endif

    let max = g:context.max_join_parts

    if max == 1
        return joined
    elseif max == 2
        return joined . ' ' . g:context.ellipsis
    endif

    if len(a:lines) > max
        call remove(a:lines, (max+1)/2, -max/2-1)
        call insert(a:lines, s:nil_line, (max+1)/2) " middle marker
    endif

    let last_number = a:lines[0].number
    for line in a:lines[1:]
        let joined.text .= ' '
        if line.number == 0
            " this is the middle marker, use long ellipsis
            let joined.text .= g:context.ellipsis5
        elseif last_number != 0 && line.number != last_number + 1
            " not after middle marker and there are lines in between: show ellipsis
            let joined.text .= g:context.ellipsis . ' '
        endif

        let joined.text .= context#line#trim(line.text)
        let last_number = line.number
    endfor

    return joined
endfunction

function! context#line#text(i, line) abort
    return a:line.text
endfunction

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
