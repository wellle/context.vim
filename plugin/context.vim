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
    let view = winsaveview()
    normal! H
    call search('.', 'c')
    let lines = []

    let line = getline('.')

    while 1
        " if line starts with closing brace: jump to matching opening one and add it to lines
        " also for other prefixes to show the if which belongs to an else etc.
        if line =~ '^\s*\([]})]\|end\|else\|case\|default\)'
            normal [=
        else
            let oldpos = getpos('.')
            normal [-
            let newpos = getpos('.')
            if newpos == oldpos
                break
            endif
        endif

        let line = getline('.')
        call insert(lines, line, 0)
        continue
    endwhile

    let oldpos = getpos('.')

    call ShowInPreview(lines)
    call winrestview(view)
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

    let l:command = "silent! pedit! +setlocal\\ " .
                  \ "buftype=nofile\\ nobuflisted\\ " .
                  \ "noswapfile\\ nonumber\\ " .
                  \ "filetype=" . &filetype . " " . s:name

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
