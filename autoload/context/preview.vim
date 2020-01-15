let s:context_buffer_name = '<context.vim>'

" TODO: remove allow_resize, force_resize?
function! context#preview#update_context(allow_resize, force_resize) abort
    let allow_resize = a:allow_resize
    let force_resize = a:force_resize

    while 1
        let base_line = context#line#get_base_line(w:context.top_line)
        let lines = context#context#get(base_line)
        let hidden_indent = s:get_hidden_indent(base_line, lines)

        call context#util#echof('> context#preview#update_context', len(lines))

        " NOTE: this overwrites lines, from here on out it's just a list of string
        call map(lines, function('context#line#display'))

        let min_height = s:get_min_height(allow_resize, force_resize)
        while len(lines) < min_height
            call add(lines, '')
        endwhile
        let w:context.min_height = len(lines)

        call s:show(lines, hidden_indent)

        call context#util#update_state()
        if w:context.needs_update
            let w:context.needs_update = 0
            " update again until it stabilizes
            let allow_resize = 0
            let force_resize = 0
            continue
        endif

        break
    endwhile
endfunction

" NOTE: this function updates the statusline too, as it depends on the padding
function! context#preview#update_padding(padding) abort
endfunction

function! context#preview#close() abort
    silent! wincmd P " jump to preview, but don't show error
    if !&previewwindow
        return
    endif

    let bufname = bufname('%')
    wincmd p " jump back

    if bufname != s:context_buffer_name
        return
    endif

    " current preview window is context, close it

    if !&equalalways
        pclose
        return
    endif

    " NOTE: if 'equalalways' is set (which it is by default) then :pclose
    " will change the window layout. here we try to restore the window
    " layout based on some help from /u/bradagy, see
    " https://www.reddit.com/r/vim/comments/e7l4m1
    set noequalalways
    pclose
    let layout = winrestcmd() | set equalalways | noautocmd execute layout
endfunction

function! s:show(lines, hidden_indent) abort
    call context#preview#close()

    if len(a:lines) == 0
        " nothing to do
        call context#util#echof('  none')
        return
    endif

    let syntax  = &syntax
    let tabstop = &tabstop
    let padding = w:context.padding

    execute 'silent! aboveleft pedit' s:context_buffer_name

    " try to jump to new preview window
    silent! wincmd P
    if !&previewwindow
        " NOTE: apparently this can fail with E242, see #6
        " in that case just silently abort
        call context#util#echof('  no preview window')
        return
    endif

    silent 0put =a:lines " paste lines
    1                    " and jump to first line

    let statusline = '%=' . s:context_buffer_name . ' ' " trailing space for padding
    if a:hidden_indent >= 0
        let statusline = repeat(' ', padding + a:hidden_indent) . g:context.ellipsis . statusline
    endif

    setlocal buftype=nofile
    setlocal modifiable
    setlocal nobuflisted
    setlocal nocursorline
    setlocal nonumber
    setlocal norelativenumber
    setlocal noswapfile
    setlocal nowrap
    setlocal signcolumn=no

    execute 'setlocal syntax='     . syntax
    execute 'setlocal tabstop='    . tabstop
    execute 'setlocal foldcolumn=' . padding
    execute 'setlocal statusline=' . escape(statusline, ' ')

    let b:airline_disable_statusline=1

    execute 'resize' len(a:lines)

    wincmd p " jump back
endfunction

" check lines above base_line, but below context lines
" return smallest indentation found, -1 if there are none
" TODO: this is potentially expensive now
" we might want to limit the number of lines we check here
function! s:get_hidden_indent(base_line, lines) abort
    call context#util#echof('> get_hidden_indent', a:base_line.number, len(a:lines))
    if len(a:lines) == 0
        " don't show ellipsis if context is empty
        return -1
    endif

    let min_indent = -1
    let max_line = a:lines[-1].number
    let current_line = a:base_line.number - 1 " first hidden line
    while current_line > max_line
        let line = getline(current_line)
        if context#line#should_skip(line)
            let current_line -= 1
            continue
        endif

        let indent = indent(current_line)
        if min_indent == -1 || min_indent > indent
            let min_indent = indent
        endif

        let current_line -= 1
    endwhile

    return min_indent
endfunction

function! s:get_min_height(allow_resize, force_resize) abort
    " adjust min window height based on scroll amount
    if a:force_resize || !exists('w:context.min_height')
        return 0
    endif

    if !a:allow_resize || w:context.scroll_offset == 0
        return w:context.min_height
    endif

    if !exists('w:context.resize_level')
        let w:context.resize_level = 0 " for decreasing window height based on scrolling
    endif

    let diff = abs(w:context.scroll_offset)
    if diff == 1
        " slowly decrease min height if moving line by line
        let w:context.resize_level += g:context.resize_linewise
    else
        " quicker if moving multiple lines (^U/^D: decrease by one line)
        let w:context.resize_level += g:context.resize_scroll / &scroll * diff
    endif

    let t = float2nr(w:context.resize_level)
    let w:context.resize_level -= t
    return w:context.min_height - t
endfunction
