let s:context_buffer_name = '<context.vim>'

" TODO: test this again
" TODO: apply total limit below (has been pushed out of context#context#get())

" TODO: try to avoid empty context lines here too?
function! context#preview#update_context() abort
    let min_height = 0

    while 1
        let base_line = context#line#get_base_line(w:context.cursor_line)
        let [context, _] = context#context#get(base_line)
        let line_number = base_line.number

        call context#util#echof('> context#preview#update_context', len(context))

        let done = 0
        let lines = []
        for per_indent in context
            if done
                break
            endif

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
                call context#util#echof('display', joined, line)
                call add(lines, line)
            endfor
        endfor

        while len(lines) < min_height
            call add(lines, context#line#make(0, 0, ''))
        endwhile
        let min_height = len(lines)

        call map(lines, function('context#line#text'))

        let indent = g:context.Indent(line_number)
        call s:show(lines, indent)

        call context#util#update_state()
        if w:context.needs_update
            let w:context.needs_update = 0
            " update again until it stabilizes
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

function! s:show(lines, indent) abort
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

    silent %d            " delete everything
    silent 0put =a:lines " paste lines
    1                    " and jump to first line

    execute 'resize' len(a:lines)

    wincmd p " jump back
endfunction
