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

function! context#line#display(index, lines) abort
    let line = a:lines[0]
    let text = s:join(a:lines)
    " return text

    " NOTE: comment out the line above to include this debug info
    let n = &columns - 30 - strchars(context#line#trim(text)) - line.indent
    return printf('%s%s // %2d %2d n:%5d i:%2d', text, repeat(' ', n), len(a:lines), a:index+1, line.number, line.indent)
endfunction

" TODO: clean up, move down?
function! s:join(lines) abort
    " call context#util#echof('> join_pending', len(a:lines))
    let joined = a:lines[0].text
    if len(a:lines) == 1
        return joined
    endif

    if g:context.max_join_parts < 3
        if g:context.max_join_parts == 2
            let joined.text .= ' ' . g:context.ellipsis
        endif
        return joined
    endif

    " TODO: probably need to fix some magic numbers (because we use lines
    " instead of pending now)
    let max = g:context.max_join_parts
    if len(a:lines) > max
        call remove(a:lines, (max)/2, -max/2-1)
        call insert(a:lines, s:nil_line, (max)/2) " middle marker
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
    return a:line =~ g:context.regex_join
endfunction
