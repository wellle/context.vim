" TODO: split this file?

function! context#util#display_line(index, line) abort
    return a:line.text

    " NOTE: comment out the line above to include this debug info
    let n = &columns - 25 - strchars(context#util#trim(a:line.text)) - a:line.indent
    return printf('%s%s // %2d n:%5d i:%2d', a:line.text, repeat(' ', n), a:index+1, a:line.number, a:line.indent)
endfunction

function context#util#trim(string) abort
    return substitute(a:string, '^\s*', '', '')
endfunction

function! context#util#extend_line(line) abort
    return a:line =~ g:context_extend_regex
endfunction

function! context#util#skip_line(line) abort
    return a:line =~ g:context_skip_regex
endfunction

function! context#util#join_line(line) abort
    return a:line =~ g:context_join_regex
endfunction

let s:log_indent = 0

function! context#util#log_indent(amount) abort
    let s:log_indent += a:amount
endfunction

" debug logging, set g:context_logfile to activate
function! context#util#echof(...) abort
    let args = join(a:000)
    let args = substitute(args, "'", '"', 'g')
    let args = substitute(args, '!', '^', 'g')
    let message = repeat(' ', s:log_indent) . args

    " echom message
    if exists('g:context_logfile')
        execute "silent! !echo '" . message . "' >>" g:context_logfile
    endif
endfunction

