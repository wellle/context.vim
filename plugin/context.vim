nnoremap <silent> <C-L> <C-L>:call <SID>show_context(1,0)<CR>
nnoremap <silent> <C-E> <C-E>:call <SID>show_context(0,0)<CR>
nnoremap <silent> <C-Y> <C-Y>:call <SID>show_context(0,0)<CR>
" NOTE: this is pretty hacky, we call zz/zt/zb twice here
" if we only do it once it seems to break something
" to reproduce: search for something, then alternate: n zt n zt n zt ...
nnoremap <silent> zz zzzz:call <SID>show_context(0,0)<CR>
nnoremap <silent> zt ztzt:call <SID>show_context(0,0)<CR>
nnoremap <silent> zb zbzb:call <SID>show_context(0,0)<CR>

" settings
let s:always_resize=0
let s:blanks_above=0

" consts
let s:buffer_name="<context.vim>"

" state
let s:min_height=0
let s:top_line=-10
let s:ignore_autocmd=0

function! s:show_context(force_resize, from_autocmd)
    if a:from_autocmd && s:ignore_autocmd
        " ignore nested calls from auto commands
        " (using the preview window triggers autocmds)
        return
    endif

    if a:force_resize || s:always_resize
        let s:top_line=-10
    endif

    call s:echof('==========', a:force_resize, a:from_autocmd)

    let s:ignore_autocmd=1
    call s:update_context(1)
    let s:ignore_autocmd=0
endfunction

function! s:update_context(allow_resize)
    let current_line = line('w0')
    call s:echof("in", s:top_line, current_line)
    if s:top_line == current_line
        return
    endif

    if a:allow_resize
        " avoid resizing if we only moved a single line
        " (so scrolling is still somewhat smooth)
        if abs(s:top_line - current_line) > 1
            let s:min_height=0
        endif
    endif

    let s:top_line = current_line
    let max_line = line('$')

    " find line which isn't empty
    while current_line <= max_line
        let line = getline(current_line)
        if !empty(matchstr(line, '[^\s]'))
            let current_indent = indent(current_line)
            break
        endif
        let current_line += 1
    endwhile

    let padding = wincol() - virtcol('.')
    let prefix = repeat(' ', padding)
    let context = []
    let current_line = s:top_line
    while current_line > 1
        let allow_same = 0

        " if line starts with closing brace: jump to matching opening one and add it to context
        " also for other prefixes to show the if which belongs to an else etc.
        if line =~ '^\s*\([]})]\|end\|else\|case\>\|default\>\)'
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
                call insert(context, prefix . line, 0)
                let current_indent = indent
                break
            endif
        endwhile
    endwhile

    let oldpos = getpos('.')

    call s:show_in_preview(context)
    " call again until it stabilizes
    " disallow resizing to make sure it will eventually
    call s:update_context(0)
endfunction

" https://vi.stackexchange.com/questions/19056/how-to-create-preview-window-to-display-a-string
function! s:show_in_preview(lines)
    pclose
    if s:min_height < len(a:lines)
        let s:min_height = len(a:lines)
    endif

    if s:min_height == 0
        return
    endif

    let &previewheight=s:min_height

    while len(a:lines) < s:min_height
        if s:blanks_above
            call insert(a:lines, "", 0)
        else
            call add(a:lines, "")
        endif
    endwhile

    execute 'silent! pedit +setlocal\ modifiable\ ' .
                  \ 'buftype=nofile\ nobuflisted\ ' .
                  \ 'noswapfile\ nonumber\ nowrap\ ' .
                  \ 'filetype=' . &filetype . " " . s:buffer_name

    call setbufline(s:buffer_name, 1, a:lines)
endfunction

augroup context.vim
    autocmd!
    au BufEnter,CursorMoved * call <SID>show_context(0,1)
augroup END

" uncomment to activate
" let s:logfile = "~/temp/vimlog"

function! s:echof(...)
    if exists('s:logfile')
        silent execute "!echo '" . join(a:000) . "' >> " . s:logfile
    endif
endfunction
