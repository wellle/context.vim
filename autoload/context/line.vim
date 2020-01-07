function! context#line#make(number, indent, text) abort
    return {
                \ 'number': a:number,
                \ 'indent': a:indent,
                \ 'text':   a:text,
                \ }
endfunction

function! context#line#display(index, line) abort
    return a:line.text

    " NOTE: comment out the line above to include this debug info
    let n = &columns - 25 - strchars(context#line#trim(a:line.text)) - a:line.indent
    return printf('%s%s // %2d n:%5d i:%2d', a:line.text, repeat(' ', n), a:index+1, a:line.number, a:line.indent)
endfunction

function! context#line#trim(string) abort
    return substitute(a:string, '^\s*', '', '')
endfunction

function! context#line#should_extend(line) abort
    return a:line =~ g:context_extend_regex
endfunction

function! context#line#should_skip(line) abort
    return a:line =~ g:context_skip_regex
endfunction

function! context#line#should_join(line) abort
    return a:line =~ g:context_join_regex
endfunction
