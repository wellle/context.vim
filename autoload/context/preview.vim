function! context#preview#get_context(base_line, allow_resize, force_resize) abort
    let lines = context#get_context(a:base_line)
    " TODO: pass this instead of using s: var?
    let s:hidden_indent = s:get_hidden_indent_for_preview(a:base_line, lines)

    " NOTE: this overwrites lines, from here on out it's just a list of string
    call map(lines, function('context#util#display_line'))

    let min_height = s:get_min_height_for_preview(a:allow_resize, a:force_resize)
    while len(lines) < min_height
        call add(lines, '')
    endwhile
    let w:context_min_height = len(lines)

    return lines
endfunction

function! context#preview#show(lines) abort
    call context#util#echof('> show_in_preview', len(a:lines))

    call context#preview#close()

    if len(a:lines) == 0
        " nothing to do
        call context#util#echof('  none')
        return
    endif

    let syntax  = &syntax
    let tabstop = &tabstop
    let padding = w:context_padding

    execute 'silent! aboveleft pedit' g:context_buffer_name

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

    setlocal buftype=nofile
    setlocal modifiable
    setlocal nobuflisted
    setlocal nocursorline
    setlocal nonumber
    setlocal norelativenumber
    setlocal noswapfile
    setlocal nowrap
    setlocal signcolumn=no
    execute 'setlocal syntax='  . syntax
    execute 'setlocal tabstop=' . tabstop
    let b:airline_disable_statusline=1
    call context#preview#update_padding(padding)

    " resize window
    execute 'resize' len(a:lines)

    wincmd p " jump back
endfunction

" NOTE: this function updates the statusline too, as it depends on the padding
" TODO: inline
function! context#preview#update_padding(padding) abort
    execute 'setlocal foldcolumn=' . a:padding

    let statusline = '%=' . g:context_buffer_name . ' ' " trailing space for padding
    if s:hidden_indent >= 0
        let statusline = repeat(' ', a:padding + s:hidden_indent) . g:context_ellipsis . statusline
    endif
    execute 'setlocal statusline=' . escape(statusline, ' ')
endfunction

function! context#preview#close() abort
    silent! wincmd P " jump to preview, but don't show error
    if !&previewwindow
        return
    endif

    let bufname = bufname('%')
    wincmd p " jump back

    if bufname != g:context_buffer_name
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


" find first line above (hidden) which isn't empty
" return its indent, -1 if no such line
" TODO: this is expensive now, maybe not do it like this? or limit it somehow?
" TODO: rename some functions now after move
function! s:get_hidden_indent_for_preview(base_line, lines) abort
    call context#util#echof('> get_hidden_indent_for_preview', a:base_line.number, len(a:lines))
    if len(a:lines) == 0
        " don't show ellipsis if context is empty
        return -1
    endif

    let min_indent = -1
    let max_line = a:lines[-1].number
    let current_line = a:base_line.number - 1 " first hidden line
    while current_line > max_line
        let line = getline(current_line)
        if context#util#skip_line(line)
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

function! s:get_min_height_for_preview(allow_resize, force_resize) abort
    " adjust min window height based on scroll amount
    if a:force_resize || !exists('w:context_min_height')
        return 0
    endif

    if !a:allow_resize || w:context_scroll_offset == 0
        return w:context_min_height
    endif

    if !exists('w:context_resize_level')
        let w:context_resize_level = 0 " for decreasing window height based on scrolling
    endif

    let diff = abs(w:context_scroll_offset)
    if diff == 1
        " slowly decrease min height if moving line by line
        let w:context_resize_level += g:context_resize_linewise
    else
        " quicker if moving multiple lines (^U/^D: decrease by one line)
        let w:context_resize_level += g:context_resize_scroll / &scroll * diff
    endif

    let t = float2nr(w:context_resize_level)
    let w:context_resize_level -= t
    return w:context_min_height - t
endfunction

