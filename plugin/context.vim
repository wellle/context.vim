nnoremap <C-L> <C-L>:call ContextR()<CR>
nnoremap <C-E> <C-E>:call Context()<CR>
nnoremap <C-Y> <C-Y>:call Context()<CR>
nnoremap <C-D> <C-D>:call ContextR()<CR>
nnoremap <C-U> <C-U>:call ContextR()<CR>
nnoremap gg gg:call ContextR()<CR>
nnoremap G G:call ContextR()<CR>
nnoremap zz zz:call ContextR()<CR>
nnoremap zt zt:call ContextR()<CR>
nnoremap zb zb:call ContextR()<CR>

" resets s:height
function! ContextR()
    let s:height=0
    call Context()
endfunction

function! Context()
    let current_line = line('w0') " topmost visible line number

    " find line which isn't empty
    while current_line > 0
        let line = getline(current_line)
        " TODO: extract helper function for this?
        if !empty(matchstr(line, '[^\s]'))
            let current_indent = indent(current_line)
            break
        endif
        let current_line += 1
    endwhile

    let context = []
    let current_line = line('w0') " topmost visible line number
    while current_line > 1
        let allow_same = 0

        " if line starts with closing brace: jump to matching opening one and add it to context
        " also for other prefixes to show the if which belongs to an else etc.
        if line =~ '^\s*\([]})]\|end\|else\|case\|default\)'
            let allow_same = 1
        endif

        " search for line with same indent (or less)
        while current_line > 1
            let current_line -= 1
            let line = getline(current_line)
            if empty(matchstr(line, '[^\s]'))
                continue " ignore empty lines
            endif

            let indent = indent(current_line)
            if indent < current_indent || allow_same && indent == current_indent
                call insert(context, line, 0)
                let current_indent = indent
                break
            endif
        endwhile
    endwhile

    let oldpos = getpos('.')

    call ShowInPreview(context)
endfunction

let s:height=0
let s:name="<context.vim>"

" https://vi.stackexchange.com/questions/19056/how-to-create-preview-window-to-display-a-string
function! ShowInPreview(lines)
    pclose
    if s:height < len(a:lines)
        let s:height = len(a:lines)
    endif

    if s:height == 0
        return
    endif

    let &previewheight=s:height
    " TODO: set winfixheight too

    let l:command = 'silent! pedit! +setlocal\ ' .
                  \ 'buftype=nofile\ nobuflisted\ ' .
                  \ 'noswapfile\ nonumber\ ' .
                  \ 'filetype=' . &filetype . " " . s:name

    exe l:command

    while len(a:lines) < s:height
        call insert(a:lines, "", 0)
    endwhile

    if has('nvim')
        let l:bufNr = bufnr(s:name)
        call nvim_buf_set_lines(l:bufNr, 0, -1, 0, a:lines)
    else
        call setbufline(s:name, 1, a:lines)
    endif
endfunction
