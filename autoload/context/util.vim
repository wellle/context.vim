" TODO: split this file?

let s:wincount = 0

function! context#util#update_state() abort
    let wincount = winnr('$')
    if s:wincount != wincount
        let s:wincount = wincount
        let w:context_needs_layout = 1
    endif

    let top_line = line('w0')
    let last_top_line = get(w:, 'context_top_line', 0)
    if last_top_line != top_line
        let w:context_top_line = top_line
        let w:context_needs_update = 1
    endif
    " used in preview only
    let w:context_scroll_offset = last_top_line - top_line

    " padding can only be checked for the current window
    let padding = wincol() - virtcol('.')
    if padding < 0
        " padding can be negative if cursor was on the wrapped part of a
        " wrapped line in that case don't take the new value
        " in this case we don't want to trigger an update, but still set
        " padding to a value
        if !exists('w:context_padding')
            let w:context_padding = 0
        endif
    elseif get(w:, 'context_padding', -1) != padding
        let w:context_padding = padding
        let w:context_needs_update = 1
    endif
endfunction

function! context#util#update_window_state(winid) abort
    let width = winwidth(a:winid)
    if getwinvar(a:winid, 'context_width') != width
        call setwinvar(a:winid, 'context_width', width)
        call setwinvar(a:winid, 'context_needs_layout', 1)
    endif

    let height = winheight(a:winid)
    if getwinvar(a:winid, 'context_height') != height
        call setwinvar(a:winid, 'context_height', height)
        call setwinvar(a:winid, 'context_needs_layout', 1)
    endif

    if g:context_presenter != 'preview'
        let screenpos = win_screenpos(a:winid)
        if getwinvar(a:winid, 'context_screenpos', []) != screenpos
            call setwinvar(a:winid, 'context_screenpos', screenpos)
            call setwinvar(a:winid, 'context_needs_layout', 1)
        endif
    endif
endfunction

function! context#util#make_line(number, indent, text) abort
    return {
                \ 'number': a:number,
                \ 'indent': a:indent,
                \ 'text':   a:text,
                \ }
endfunction

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

