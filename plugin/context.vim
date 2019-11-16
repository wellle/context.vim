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
let g:context_enabled = get(g:, 'context_enabled', 1)

let s:always_resize = 0
let s:max_height = 21
let s:max_height_per_indent = 5
let s:ellipsis_char = '·'

" consts
let s:buffer_name = '<context.vim>'

" state
let s:min_height = 0
let s:top_line = -10
let s:ignore_autocmd = 0

function! s:show_context(force_resize, autocmd) abort
    if !g:context_enabled
        return
    endif

    if &previewwindow
        " no context of preview windows (which we use to display context)
        call s:echof('abort preview')
        return
    endif

    if mode() != 'n'
        call s:echof('abort mode')
        return
    endif

    call s:echof('> show_context', a:force_resize, a:autocmd)
    if a:autocmd && s:ignore_autocmd
        " ignore nested calls from auto commands
        call s:echof('abort from autocmd')
        return
    endif

    call s:echof('==========', a:force_resize, a:autocmd)
    if a:force_resize || s:always_resize
        let s:top_line = -10
    endif

    let s:ignore_autocmd = 1
    call s:update_context(1)
    let s:ignore_autocmd = 0
endfunction

function! s:update_context(allow_resize) abort
    let current_line = line('w0')
    call s:echof('top line', s:top_line, current_line)
    if s:top_line == current_line
        return
    endif

    if a:allow_resize
        " avoid resizing if we only moved a single line
        " (so scrolling is still somewhat smooth)
        if abs(s:top_line - current_line) > 1
            let s:min_height = 0
        endif
    endif

    let s:top_line = current_line
    let max_line = line('$')

    " find line which isn't empty
    while current_line <= max_line
        let line = getline(current_line)
        if !s:skip_line(line)
            let current_indent = indent(current_line)
            break
        endif
        let current_line += 1
    endwhile

    let context = {}
    let line_count = 0
    let current_line = s:top_line
    while current_line > 1
        let allow_same = 0

        " if line starts with closing brace: jump to matching opening one and add it to context
        " also for other prefixes to show the if which belongs to an else etc.
        if line =~ '^\s*\([]{})]\|end\|else\|case\>\|default\>\)'
            let allow_same = 1
        endif

        " search for line with same indent (or less)
        while current_line > 1
            let current_line -= 1
            let line = getline(current_line)
            if s:skip_line(line)
                continue " ignore empty lines
            endif

            let indent = indent(current_line)
            if indent < current_indent || allow_same && indent == current_indent
                if !has_key(context, indent)
                    let context[indent] = []
                endif
                call insert(context[indent], line, 0)
                let line_count += 1
                let current_indent = indent
                break
            endif
        endwhile
    endwhile

    let diff_want = line_count - s:min_height
    let max = s:max_height_per_indent
    let lines = []
    let indents = []
    " no more than five lines per indent
    for indent in sort(keys(context), 'N')
        if diff_want > 0
            let diff = len(context[indent]) - max
            if diff > 0
                let diff2 = diff - diff_want
                if diff2 > 0
                    let max += diff2
                    let diff -= diff2
                endif

                let ellipsis_line = repeat(' ', indent) . repeat(s:ellipsis_char, 3)
                call remove(context[indent], max/2, -(max+1)/2)
                call insert(context[indent], ellipsis_line, max/2)
                let diff_want -= diff
            endif
        endif
        call extend(lines, context[indent])
        call extend(indents, repeat([indent], len(context[indent])))
    endfor

    let max = s:max_height
    if len(lines) > max
        let indent1 = indents[max/2]
        let indent2 = indents[-(max-1)/2]
        let ellipsis = repeat(s:ellipsis_char, max([indent2 - indent1, 3]))
        let ellipsis_line = repeat(' ', indent1) . ellipsis
        call remove(lines, max/2, -(max+1)/2)
        call insert(lines, ellipsis_line, max/2)
    endif

    call s:show_in_preview(lines)
    " call again until it stabilizes
    " disallow resizing to make sure it will eventually
    call s:update_context(0)
endfunction

function! s:skip_line(line) abort
    return a:line =~ '^\s*\($\|//\)'
endfunction

function! s:show_in_preview(lines) abort
    if s:min_height < len(a:lines)
        let s:min_height = len(a:lines)
    endif

    let filetype = &filetype
    let padding = wincol() - virtcol('.')

    " based on https://stackoverflow.com/questions/13707052/quickfix-preview-window-resizing
    silent! wincmd P " jump to preview, but don't show error
    if &previewwindow
        if bufname() == s:buffer_name
            " reuse existing preview window
            call s:echof('reuse')
            silent %delete _
        elseif s:min_height == 0
            " nothing to do
            call s:echof('not ours')
            wincmd p " jump back
            return
        else
            call s:echof('take over')
            call s:open_preview(filetype, padding)
        endif

    elseif s:min_height == 0
        " nothing to do
        call s:echof('none')
        return
    else
        call s:echof('open new')
        call s:open_preview(filetype, padding)
        wincmd P " jump to new preview window
    endif

    while len(a:lines) < s:min_height
        call add(a:lines, "")
    endwhile

    silent 0put =a:lines " paste lines
    1                    " and jump to first line

    " update padding
    execute 'setlocal foldcolumn=' . padding
    let s:padding = padding

    " resize window
    execute 'resize' s:min_height

    wincmd p " jump back
endfunction

" https://vi.stackexchange.com/questions/19056/how-to-create-preview-window-to-display-a-string
function! s:open_preview(filetype, padding) abort
    let settings = '+setlocal'   .
                \ ' buftype='    . 'nofile'      .
                \ ' filetype='   . a:filetype    .
                \ ' statusline=' . s:buffer_name .
                \ ' modifiable'  .
                \ ' nobuflisted' .
                \ ' nonumber'    .
                \ ' noswapfile'  .
                \ ' nowrap'      .
                \ ''
    execute 'silent! pedit' escape(settings, ' ') s:buffer_name
endfunction

function! s:enable() abort
    let g:context_enabled = 1
    call s:show_context(1, 0)
endfunction

function! s:disable() abort
    let g:context_enabled = 0

    silent! wincmd P " jump to new preview window
    if &previewwindow
        let bufname = bufname()
        wincmd p " jump back
        if bufname == s:buffer_name
            " if current preview window is context, close it
            pclose
        endif
    endif
endfunction

function! s:toggle() abort
    if g:context_enabled
        call s:disable()
    else
        call s:enable()
    endif
endfunction

function! s:update_padding(autocmd) abort
    if !g:context_enabled
        return
    endif

    if &previewwindow
        " no context of preview windows (which we use to display context)
        call s:echof('abort preview')
        return
    endif

    if mode() != 'n'
        call s:echof('abort mode')
        return
    endif

    call s:echof('> update_padding', a:autocmd)
    let padding = wincol() - virtcol('.')

    if exists('s:padding') && s:padding == padding
        call s:echof('abort same padding', s:padding, padding)
        return
    endif

    silent! wincmd P
    if !&previewwindow
        call s:echof('abort no preview')
        return
    endif

    if bufname() != s:buffer_name
        call s:echof('abort different preview')
        wincmd p
        return
    endif

    call s:echof('update padding', padding, a:autocmd)
    execute 'setlocal foldcolumn=' . padding
    let s:padding = padding
    wincmd p
endfunction

command! -bar ContextEnable  call s:enable()
command! -bar ContextDisable call s:disable()
command! -bar ContextToggle  call s:toggle()

augroup context.vim
    autocmd!
    autocmd BufEnter *     call <SID>show_context(0, 'BufEnter')
    autocmd CursorMoved *  call <SID>show_context(0, 'CursorMoved')
    autocmd User GitGutter call <SID>update_padding('GitGutter')
augroup END

" uncomment to activate
" let s:logfile = '~/temp/vimlog'

function! s:echof(...) abort
    if exists('s:logfile')
        execute "silent! !echo '" . join(a:000) . "' >>" s:logfile
    endif
endfunction
