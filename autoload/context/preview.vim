let s:context_buffer_name = '<context.vim>'

function! context#preview#update_context() abort
    let min_height = 0

    while 1
        let base_line = context#line#get_base_line(w:context.top_line)
        let lines = context#context#get(base_line)
        let hidden_indent = s:get_hidden_indent(base_line, lines)

        call context#util#echof('> context#preview#update_context', len(lines))

        " NOTE: this overwrites lines, from here on out it's just a list of string
        call map(lines, function('context#line#display'))

        while len(lines) < min_height
            call add(lines, '')
        endwhile
        let min_height = len(lines)

        call s:show(lines, hidden_indent)

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

" returns indent of first nonempty hidden line
function! s:get_hidden_indent(base_line, lines) abort
    call context#util#echof('> get_hidden_indent', a:base_line.number, len(a:lines))
    if len(a:lines) == 0
        " don't show ellipsis if context is empty
        return -1
    endif

    let max_line = a:lines[-1].number
    let current_line = a:base_line.number - 1 " first hidden line
    while current_line > max_line
        let line = getline(current_line)
        if context#line#should_skip(line)
            let current_line -= 1
            continue
        endif

        return indent(current_line)
    endwhile

    return -1
endfunction
