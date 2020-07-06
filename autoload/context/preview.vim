let s:context_buffer_name = '<context.vim>'

function! context#preview#update_context() abort
    let min_height = 0

    while 1
        let [lines, base_line] = context#preview#get_context()
        let indent = g:context.Indent(base_line)

        while len(lines) < min_height
            " TODO: try to avoid empty context lines here too?
            call add(lines, '')
        endwhile
        let min_height = len(lines)

        call context#preview#close()
        call s:show(lines, indent)

        call context#util#update_state() " NOTE: this might set w:context.needs_update
        if !w:context.needs_update
            return
        endif

        " TODO: can we set this above the update_state call? would be more compact
        let w:context.needs_update = 0
        " update again until it stabilizes
    endwhile
endfunction

function! context#preview#get_context() abort
    let base_line = context#line#get_base_line(w:context.cursor_line)
    let [context, _] = context#context#get(base_line)
    let line_number = base_line.number

    call context#util#echof('> context#preview#update_context', len(context))

    let max_height = g:context.max_height
    let max_height_per_indent = g:context.max_per_indent

    let done = 0
    let lines = []
    for per_indent in context
        if done
            break
        endif

        let inner_lines = []
        for joined in per_indent
            if done
                break
            endif

            if joined[0].number >= w:context.top_line
                let line_number = joined[0].number
                let done = 1
                break
            endif

            for i in range(1, len(joined)-1)
                " call context#util#echof('joined ', i, joined[0].number, w:context.top_line, len(out))
                if joined[i].number >= w:context.top_line
                    let line_number = joined[i].number
                    let done = 1
                    call remove(joined, i, -1)
                    break " inner loop
                endif
            endfor

            let line = context#line#display(joined)
            " call context#util#echof('display', joined, line)
            call add(inner_lines, line)
        endfor

        " TODO: extract function (used in preview too)
        " apply max per indent
        if len(inner_lines) <= max_height_per_indent
            call extend(lines, inner_lines)
            continue
        endif

        let diff = len(inner_lines) - max_height_per_indent

        let indent = inner_lines[0].indent
        let limited = inner_lines[: max_height_per_indent/2-1]
        let ellipsis_line = context#line#make(0, indent, repeat(' ', indent) . g:context.ellipsis)
        call add(limited, ellipsis_line)
        call extend(limited, inner_lines[-(max_height_per_indent-1)/2 :])

        call extend(lines, limited)
    endfor

    " TODO: extract function (used in popup too)
    " apply total limit
    if len(lines) > max_height
        let indent1 = lines[max_height/2].indent
        let indent2 = lines[-(max_height-1)/2].indent
        let ellipsis = repeat(g:context.char_ellipsis, max([indent2 - indent1, 3]))
        " TODO: test this
        let ellipsis_line = context#line#make(0, indent1, repeat(' ', indent1) . ellipsis)
        call remove(lines, max_height/2, -(max_height+1)/2)
        call insert(lines, ellipsis_line, max_height/2)
    endif

    call map(lines, function('context#line#text'))

    return [lines, line_number]
endfunction

" NOTE: this function updates the statusline too, as it depends on the padding
" TODO: delete this function? why is it empty?
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

function! s:show(lines, indent) abort
    if len(a:lines) == 0
        " nothing to do
        call context#util#echof('  none')
        return [[], 0]
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
        return [[], 0]
    endif

    let statusline = '%=' . s:context_buffer_name . ' ' " trailing space for padding
    if a:indent >= 0
        let statusline = repeat(' ', padding + a:indent) . g:context.ellipsis . statusline
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

    silent %d _          " delete everything
    silent 0put =a:lines " paste lines
    1                    " and jump to first line

    execute 'resize' len(a:lines)

    wincmd p " jump back
endfunction
