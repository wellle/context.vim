let s:context_buffer_name = '<context.vim>'

function! context#preview#update_context() abort
    while 1
        let context = context#preview#get_context()

        call context#preview#close()
        call s:show(context)

        let w:context.needs_update = 0
        if context.line_count == 0
            " NOTE: this check avoids an endless loop if we run into the case
            " where we don't show the context because it was too big
            return
        endif

        call context#util#update_state() " NOTE: this might set w:context.needs_update
        if !w:context.needs_update
            return
        endif

        " update again until it stabilizes
    endwhile
endfunction

let s:empty_context = {'line_count': 0, 'height': 0}

function! context#preview#get_context() abort
    call context#util#echof('preview get_context')
    let max_height = winheight(0) - &scrolloff - 2
    if max_height <= 0
        return s:empty_context
    endif

    let top_line  = w:context.top_line
    let base_line = context#line#get_base_line(w:context.cursor_line)
    let context   = context#context#get(base_line)

    if context.top_line.number >= top_line
        " context's top line can be visible on screen: don't show context
        return s:empty_context
    endif

    while 1
        let parent_context = context#context#get(context.bottom_line)
        " bottom line of context would not be visible if if we would show
        " parent_context, so pick context instead
        if context.bottom_line.number < top_line
            break
        endif
        let context = parent_context
    endwhile

    if context.height > max_height
        return s:empty_context
    endif

    return context
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

function! s:show(context) abort
    if a:context.line_count == 0
        " nothing to do
        call context#util#echof('  none')
        return
    endif

    let winid = win_getid()
    let list  = &list

    execute 'silent! aboveleft pedit' s:context_buffer_name

    " try to jump to new preview window
    silent! wincmd P
    if !&previewwindow
        " NOTE: apparently this can fail with E242, see #6
        " in that case just silently abort
        call context#util#echof('  no preview window')
        return
    endif

    let display_lines = a:context.display_lines[: -2]
    let border_line   = a:context.display_lines[-1]
    let hls           = a:context.highlights[: -2]
    let border_hls    = a:context.highlights[-1]

    let statusline = ''
    for hl in border_hls
        let part = strpart(border_line, hl[1], hl[2])
        let statusline .= '%#' . hl[0] . '#' . part
    endfor

    let &list = list
    setlocal buftype=nofile
    setlocal modifiable
    setlocal nobuflisted
    setlocal nocursorline
    setlocal nonumber
    setlocal norelativenumber
    setlocal noswapfile
    setlocal nowrap
    setlocal signcolumn=no

    execute 'setlocal statusline=' . escape(statusline, ' ')

    let b:airline_disable_statusline=1

    silent %d _                " delete everything
    silent 0put =display_lines " paste lines
    1                          " and jump to first line

    for h in range(0, len(hls)-1)
        for hl in hls[h]
            call matchaddpos(hl[0], [[h+1, hl[1]+1, hl[2]]], 10, -1)
        endfor
    endfor

    execute 'resize' a:context.line_count

    wincmd p " jump back
endfunction
