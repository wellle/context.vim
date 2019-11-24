nnoremap <silent> <C-L> <C-L>:call <SID>show_context(1, 0)<CR>
nnoremap <silent> <C-E> <C-E>:call <SID>show_context(0, 0)<CR>
nnoremap <silent> <C-Y> <C-Y>:call <SID>show_context(0, 0)<CR>
" NOTE: this is pretty hacky, we call zz/zt/zb twice here
" if we only do it once it seems to break something
" to reproduce: search for something, then alternate: n zt n zt n zt ...
nnoremap <silent> zz zzzz:call <SID>show_context(0, 0)<CR>
nnoremap <silent> zt ztzt:call <SID>show_context(0, 0)<CR>
nnoremap <silent> zb zbzb:call <SID>show_context(0, 0)<CR>

" settings
let g:context_enabled = get(g:, 'context_enabled', 1)

let s:always_resize = 0
let s:max_height = 21
let s:max_height_per_indent = 5
let s:max_join_parts = 5
let s:ellipsis_char = '·'

" consts
let s:buffer_name = '<context.vim>'

" cached
let s:ellipsis = repeat(s:ellipsis_char, 3)

" state
let s:enabled = 0
let s:last_winnr = -1
let s:last_bufnr = -1
let s:last_top_line = -10
let s:min_height = 0
let s:padding = 0
let s:ignore_autocmd = 0

function! s:show_context(force_resize, autocmd) abort
    if !g:context_enabled || !s:enabled
        " call s:echof(' disabled')
        return
    endif

    if &previewwindow
        " no context of preview windows (which we use to display context)
        " call s:echof(' abort preview')
        return
    endif

    if mode() != 'n'
        " call s:echof(' abort mode')
        return
    endif

    if type(a:autocmd) == type('') && s:ignore_autocmd
        " ignore nested calls from auto commands
        " call s:echof(' abort from autocmd')
        return
    endif

    call s:echof('> show_context', a:force_resize, a:autocmd)

    let s:ignore_autocmd = 1
    let s:log_indent += 1
    call s:update_context(1, a:force_resize)
    let s:log_indent -= 1
    let s:ignore_autocmd = 0
endfunction

function! s:update_context(allow_resize, force_resize) abort
    call s:echof('> update_context', a:allow_resize, a:force_resize)

    let winnr = winnr()
    let bufnr = bufnr('%')
    let current_line = line('w0')

    if a:force_resize || s:always_resize || (a:allow_resize &&
                \ s:last_winnr == winnr &&
                \ abs(s:last_top_line - current_line) > 1)
        " avoid resizing when jumping between windows
        " might not be needed when using pclose
        let s:min_height = 0
    endif

    if !a:force_resize && s:last_bufnr == bufnr && s:last_top_line == current_line
        call s:echof(' abort same buf and top line', bufnr, current_line)
        return
    endif

    let s:last_winnr = winnr
    let s:last_bufnr = bufnr
    let s:last_top_line = current_line

    " find first line above (hidden) which isn't empty
    let s:hidden_indent = 0 " in case there is none
    let current_line = s:last_top_line - 1 " first hidden line
    while current_line > 0
        let line = getline(current_line)
        if !s:skip_line(line)
            let s:hidden_indent = indent(current_line)
            break
        endif
        let current_line -= 1
    endwhile

    " find line downwards which isn't empty
    let max_line = line('$')
    let current_indent = 0 " in case there are no nonempty lines below
    let current_line = s:last_top_line
    while current_line <= max_line
        let line = getline(current_line)
        if !s:skip_line(line)
            let current_indent = indent(current_line)
            break
        endif
        let current_line += 1
    endwhile

    if s:hidden_indent < current_indent
        let s:hidden_indent = 0
    endif

    " collect all context lines
    let context = {}
    let line_count = 0
    let current_line = s:last_top_line
    while current_line > 1
        let allow_same = 0

        " if line starts with closing brace: jump to matching opening one and add it to context
        " also for other prefixes to show the if which belongs to an else etc.
        if line =~ '^\s*\([]{})]\|end\|else\|case\>\|default\>\)'
            let allow_same = 1
        elseif current_indent == 0
            break
        endif

        " search for line with same indent (or less)
        while current_line > 1
            let current_line -= 1
            let line = getline(current_line)
            if s:skip_line(line)
                continue " ignore empty lines
            endif

            let indent = indent(current_line)
            if indent < current_indent || allow_same && indent == current_indent
                if !has_key(context, indent)
                    let context[indent] = []
                endif
                call insert(context[indent], line, 0)
                let line_count += 1
                let current_indent = indent
                break
            endif
        endwhile
    endwhile

    " limit context per intend
    let diff_want = line_count - s:min_height
    let max = s:max_height_per_indent
    let lines = []
    let indents = []
    " no more than five lines per indent
    for indent in sort(keys(context), 'N')
        if diff_want > 0
            let context[indent] = s:join(context[indent])
            let diff = len(context[indent]) - max
            if diff > 0
                let diff2 = diff - diff_want
                if diff2 > 0
                    let max += diff2
                    let diff -= diff2
                endif

                let ellipsis_line = repeat(' ', indent) . s:ellipsis
                call remove(context[indent], max/2, -(max+1)/2)
                call insert(context[indent], ellipsis_line, max/2)
                let diff_want -= diff
            endif
        endif
        call extend(lines, context[indent])
        call extend(indents, repeat([indent], len(context[indent])))
    endfor

    " limit total context
    let max = s:max_height
    if len(lines) > max
        let indent1 = indents[max/2]
        let indent2 = indents[-(max-1)/2]
        let ellipsis = repeat(s:ellipsis_char, max([indent2 - indent1, 3]))
        let ellipsis_line = repeat(' ', indent1) . ellipsis
        call remove(lines, max/2, -(max+1)/2)
        call insert(lines, ellipsis_line, max/2)
    endif

    let s:log_indent += 1
    call s:show_in_preview(lines)
    let s:log_indent -= 1
    " call again until it stabilizes
    " disallow resizing to make sure it will eventually
    let s:log_indent += 1
    call s:update_context(0, 0)
    let s:log_indent -= 1
endfunction

function! s:skip_line(line) abort
    return a:line =~ '^\s*\($\|//\)'
endfunction

function! s:join(lines) abort
    " only works with at least 3 parts, so disable otherwise
    if s:max_join_parts < 3
        return a:lines
    endif

    " call s:echof('> join')
    let pending = [] " lines which might be joined with previous
    let joined = a:lines[:0] " start with first line
    for line in a:lines[1:]
        if line =~ '^\W*$'
            " add lines without word characters to pending list
            call add(pending, line)
            continue
        endif

        " don't join lines with word characters
        " but first join pending lines to previous output line
        let joined[-1] .= s:join_pending(pending)
        let pending = []
        call add(joined, line)
    endfor

    " join remaining pending lines to last
    let joined[-1] .= s:join_pending(pending)
    return joined
endfunction

function! s:join_pending(pending) abort
    " call s:echof('> join_pending', len(a:pending))
    if len(a:pending) == 0
        return ''
    endif

    let max = s:max_join_parts
    if len(a:pending) > max-1
        call remove(a:pending, (max-1)/2-1, -max/2-1)
        call insert(a:pending, '', (max-1)/2-1)
    endif

    let suffix = ''
    let space = ' '
    for line in a:pending
        if line == ''
            let suffix .= ' ' . s:ellipsis
            let space = '' " avoid space between this double ellipsis
        else
            let suffix .= space . s:ellipsis . ' ' . trim(line)
            let space = ' '
        endif
    endfor
    return suffix
endfunction

function! s:show_in_preview(lines) abort
    call s:echof('> show_in_preview', len(a:lines))

    if s:min_height < len(a:lines)
        let s:min_height = len(a:lines)
    endif

    let filetype = &filetype
    let tabstop  = &tabstop
    let padding = wincol() - virtcol('.')

    " based on https://stackoverflow.com/questions/13707052/quickfix-preview-window-resizing
    silent! wincmd P " jump to preview, but don't show error
    if &previewwindow
        if bufname('%') == s:buffer_name
            " reuse existing preview window
            call s:echof(' reuse')
            silent %delete _
        elseif s:min_height == 0
            " nothing to do
            call s:echof(' not ours')
            wincmd p " jump back
            return
        else
            call s:echof(' take over')
            let s:log_indent += 1
            call s:open_preview()
            let s:log_indent -= 1
        endif

    elseif s:min_height == 0
        " nothing to do
        call s:echof(' none')
        return
    else
        call s:echof(' open new')
        let s:log_indent += 1
        call s:open_preview()
        let s:log_indent -= 1
        wincmd P " jump to new preview window
    endif

    while len(a:lines) < s:min_height
        call add(a:lines, "")
    endwhile

    silent 0put =a:lines " paste lines
    1                    " and jump to first line

    execute 'setlocal filetype=' . filetype
    execute 'setlocal tabstop='  . tabstop
    call s:set_padding(padding)

    " resize window
    execute 'resize' s:min_height

    wincmd p " jump back
endfunction

" https://vi.stackexchange.com/questions/19056/how-to-create-preview-window-to-display-a-string
function! s:open_preview() abort
    call s:echof('> open_preview')
    let settings = '+setlocal'      .
                \ ' buftype=nofile' .
                \ ' modifiable'     .
                \ ' nobuflisted'    .
                \ ' nonumber'       .
                \ ' noswapfile'     .
                \ ' nowrap'         .
                \ ''
    execute 'silent! pedit' escape(settings, ' ') s:buffer_name
endfunction

function! s:enable() abort
    let g:context_enabled = 1
    call s:show_context(1, 0)
endfunction

function! s:disable() abort
    let g:context_enabled = 0

    silent! wincmd P " jump to new preview window
    if &previewwindow
        let bufname = bufname('%')
        wincmd p " jump back
        if bufname == s:buffer_name
            " if current preview window is context, close it
            pclose
        endif
    endif
endfunction

function! s:toggle() abort
    if g:context_enabled
        call s:disable()
    else
        call s:enable()
    endif
endfunction

function! s:update_padding(autocmd) abort
    " call s:echof('> update_padding', a:autocmd)
    if !g:context_enabled
        return
    endif

    if &previewwindow
        " no context of preview windows (which we use to display context)
        " call s:echof(' abort preview')
        return
    endif

    if mode() != 'n'
        " call s:echof(' abort mode')
        return
    endif

    let padding = wincol() - virtcol('.')

    if s:padding == padding
        " call s:echof(' abort same padding', s:padding, padding)
        return
    endif

    silent! wincmd P
    if !&previewwindow
        " call s:echof(' abort no preview')
        return
    endif

    if bufname('%') != s:buffer_name
        " call s:echof(' abort different preview')
        wincmd p
        return
    endif

    " call s:echof(' update padding', padding, a:autocmd)
    call s:set_padding(padding)
    wincmd p
endfunction

" NOTE: this function updates the statusline too, as it depends on the padding
function! s:set_padding(padding) abort
    let padding = a:padding
    if padding >= 0
        execute 'setlocal foldcolumn=' . padding
        let s:padding = padding
    else
        " padding can be negative if cursor was on the wrapped part of a wrapped line
        " in that case don't try to apply it, but still update the statusline
        " using the last known padding value
        let padding = s:padding
    endif

    let statusline = '%=' . s:buffer_name
    if s:hidden_indent > 0
        let statusline = repeat(' ', padding + s:hidden_indent) . s:ellipsis . statusline
    endif
    execute 'setlocal statusline=' . escape(statusline, ' ')
endfunction

function! s:vim_enter() abort
    " for some reason there seems to be a race when we try to show context of
    " one buffer before another one gets opened in startup
    " to avoid that we wait for startup to be finished
    let s:enabled = 1
    call s:show_context(0, 'VimEnter')
endfunction

command! -bar ContextEnable  call s:enable()
command! -bar ContextDisable call s:disable()
command! -bar ContextToggle  call s:toggle()

augroup context.vim
    autocmd!
    autocmd VimEnter *     call <SID>vim_enter()
    autocmd BufAdd *       call <SID>show_context(1, 'BufAdd')
    autocmd BufEnter *     call <SID>show_context(0, 'BufEnter')
    autocmd CursorMoved *  call <SID>show_context(0, 'CursorMoved')
    autocmd User GitGutter call <SID>update_padding('GitGutter')
augroup END

" uncomment to activate
" let s:logfile = '~/temp/vimlog'
let s:log_indent = 0

function! s:echof(...) abort
    if exists('s:logfile')
        execute "silent! !echo '" . repeat(' ', s:log_indent) . join(a:000) . "' >>" s:logfile
    endif
endfunction
