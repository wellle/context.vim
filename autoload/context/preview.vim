let s:context_buffer_name = '<context.vim>'

" TODO!: make work for preview
" TODO!: use smart statusline to look like in popup

function! context#preview#update_context() abort
    while 1
        let [lines, base_line] = context#preview#get_context()
        let indent = g:context.Indent(base_line)

        call context#preview#close()
        call s:show(lines, indent)

        let w:context.needs_update = 0
        call context#util#update_state() " NOTE: this might set w:context.needs_update
        if !w:context.needs_update
            return
        endif

        " update again until it stabilizes
    endwhile
endfunction

function! context#preview#get_context() abort
    let base_line = context#line#get_base_line(w:context.cursor_line)
    let [context, _] = context#context#get(base_line)
    let line_number = base_line.number

    call context#util#echof('> context#preview#update_context', len(context))

    let [lines, line_number] = context#util#filter(context, line_number, 0)

    return [lines, line_number]
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
