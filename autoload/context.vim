" consts
let s:buffer_name = '<context.vim>'

" cached
let s:ellipsis  = repeat(g:context_ellipsis_char, 3)
let s:ellipsis5 = repeat(g:context_ellipsis_char, 5)
let s:nil_line  = {'number': 0, 'indent': 0, 'text': ''}

" state
" NOTE: there's more state in window local w: variables
let s:activated      = 0
let s:last_winid     = 0
let s:ignore_autocmd = 0
let s:log_indent     = 0


" call this on VimEnter to activate the plugin
function! context#activate() abort
    " for some reason there seems to be a race when we try to show context of
    " one buffer before another one gets opened in startup
    " to avoid that we wait for startup to be finished
    let s:activated = 1
    call context#update(0, 'VimEnter')
endfunction

function! context#enable() abort
    let g:context_enabled = 1
    call context#update(1, 0)
endfunction

function! context#disable() abort
    let g:context_enabled = 0

    silent! wincmd P " jump to new preview window
    if &previewwindow
        let bufname = bufname('%')
        wincmd p " jump back
        if bufname == s:buffer_name
            " if current preview window is context, close it
            pclose
        endif
    endif
endfunction

function! context#toggle() abort
    if g:context_enabled
        call context#disable()
    else
        call context#enable()
    endif
endfunction


function! context#update(force_resize, autocmd) abort
    if !g:context_enabled ||
    \  !s:activated ||
    \  index(g:context_filetype_blacklist, &filetype) != -1
        " call s:echof('  disabled')
        return
    endif

    if &previewwindow
        " no context of preview windows (which we use to display context)
        " call s:echof('  abort preview')
        return
    endif

    if mode() != 'n'
        " call s:echof('  abort mode')
        return
    endif

    if type(a:autocmd) == type('') && s:ignore_autocmd
        " ignore nested calls from auto commands
        " call s:echof('  abort from autocmd')
        return
    endif

    call s:echof()
    call s:echof('> update', a:force_resize, a:autocmd)

    let s:ignore_autocmd = 1
    let s:log_indent += 2
    call s:update_context(1, a:force_resize)
    let s:log_indent -= 2
    let s:ignore_autocmd = 0
endfunction

function! context#clear_cache() abort
    " this dictionary maps a line to its next context line
    " so it allows us to skip large portions of the buffer instead of always
    " having to scan through all of it
    let b:context_skips = {}
    let b:context_cost  = 0
    let b:context_saved = 0
endfunction

function! context#cache_stats() abort
    let skips = len(b:context_skips)
    let cost  = b:context_cost
    let total = b:context_cost + b:context_saved
    echom printf('cache: %d skips, %d / %d (%.1f%%)', skips, cost, total, 100.0 * cost / total)
endfunction

function! context#update_padding(autocmd) abort
    " call s:echof('> update_padding', a:autocmd)
    if !g:context_enabled
        return
    endif

    if &previewwindow
        " no context of preview windows (which we use to display context)
        " call s:echof('  abort preview')
        return
    endif

    if mode() != 'n'
        " call s:echof('  abort mode')
        return
    endif

    let padding = wincol() - virtcol('.')

    if exists('w:padding') && w:padding == padding
        " call s:echof('  abort same padding', w:padding, padding)
        return
    endif

    silent! wincmd P
    if !&previewwindow
        " call s:echof('  abort no preview')
        return
    endif

    if bufname('%') != s:buffer_name
        " call s:echof('  abort different preview')
        wincmd p
        return
    endif

    " call s:echof('  update padding', padding, a:autocmd)
    call s:set_padding(padding)
    wincmd p
endfunction


" this function actually updates the context and calls itself until it stabilizes
function! s:update_context(allow_resize, force_resize) abort
    let winid = win_getid()
    let current_line = line('w0')

    call s:echof('> update_context', a:allow_resize, a:force_resize, winid, current_line)

    if !a:force_resize && s:last_winid == winid && w:last_top_line == current_line
        call s:echof('  abort same win and top line')
        return
    endif

    if !exists('w:last_top_line')
        let w:last_top_line = -10
    endif

    " adjust min window height based on scroll amount
    if a:force_resize || !exists('w:min_height')
        let w:min_height = 0
    elseif a:allow_resize && w:last_top_line != current_line
        if !exists('w:resize_level')
            let w:resize_level = 0 " for decreasing window height based on scrolling
        endif

        let diff = abs(w:last_top_line - current_line)
        if diff == 1
            " slowly decrease min height if moving line by line
            let w:resize_level += g:context_resize_linewise
        else
            " quicker if moving multiple lines (^U/^D: decrease by one line)
            let w:resize_level += g:context_resize_scroll / &scroll * diff
        endif
        let t = float2nr(w:resize_level)
        let w:resize_level -= t
        let w:min_height -= t
    endif

    let s:last_winid = winid
    let w:last_top_line = current_line

    let s:hidden_line = s:get_hidden_line(current_line)
    let base_line = s:get_base_line(current_line)
    let [context, context_len] = s:get_context(base_line)

    " limit context per indent
    let diff_want = context_len - w:min_height
    let lines = []
    " no more than five lines per indent
    for indent in sort(keys(context), 'N')
        let [context[indent], diff_want] = s:join(context[indent], diff_want)
        let [context[indent], diff_want] = s:limit(context[indent], diff_want, indent)
        call extend(lines, context[indent])
    endfor

    if len(lines) == 0
        " don't show ellipsis if context is empty
        let s:hidden_line = s:nil_line
    endif

    " limit total context
    let max = g:context_max_height
    if len(lines) > max
        let indent1 = lines[max/2].indent
        let indent2 = lines[-(max-1)/2].indent
        let ellipsis = repeat(g:context_ellipsis_char, max([indent2 - indent1, 3]))
        let ellipsis_line = s:make_line(0, indent1, repeat(' ', indent1) . ellipsis)
        call remove(lines, max/2, -(max+1)/2)
        call insert(lines, ellipsis_line, max/2)
    endif

    let s:log_indent += 2
    call s:show_in_preview(lines)
    " call again until it stabilizes
    " disallow resizing to make sure it will eventually
    call s:update_context(0, 0)
    let s:log_indent -= 2
endfunction

" find first line above (hidden) which isn't empty
function! s:get_hidden_line(top_line) abort
    let current_line = a:top_line - 1 " first hidden line
    while current_line > 0
        let line = getline(current_line)
        if s:skip_line(line)
            let current_line -= 1
            continue
        endif

        return s:make_line(current_line, indent(current_line), line)
        break
    endwhile

    return s:nil_line " nothing found
endfunction

" find line downwards (from top line) which isn't empty
function! s:get_base_line(top_line) abort
    let current_line = a:top_line
    let max_line = line('$')
    while current_line <= max_line
        let line = getline(current_line)
        if s:skip_line(line)
            let current_line += 1
            continue
        endif

        return s:make_line(current_line, indent(current_line), line)
    endwhile

    " nothing found
    return s:nil_line
endfunction

" collect all context lines
function! s:get_context(line) abort
    let base_line = a:line
    if base_line.number == 0
        return [{}, 0]
    endif

    let context = {}
    let context_len = 0

    if !exists('b:context_skips')
        let b:context_skips = {}
    endif

    while 1
        let context_line = s:get_context_line(base_line)
        let b:context_skips[base_line.number] = context_line.number " cache this lookup

        if context_line.number == 0
            return [context, context_len]
        endif

        let indent = context_line.indent
        if !has_key(context, indent)
            let context[indent] = []
        endif

        call insert(context[indent], context_line, 0)
        let context_len += 1

        if s:hidden_line.number == context_line.number
            " don't show ellipsis if hidden line is part of context
            let s:hidden_line = s:nil_line
        endif

        " for next iteration
        let base_line = context_line
    endwhile
endfunction

function! s:get_context_line(line) abort
    " this is a very primitive way of counting how many lines we scan in total
    " highly unscientific, but can the effect of our caching and where it
    " should be improved
    if !exists('b:context_cost')
        let b:context_cost  = 0
        let b:context_saved = 0
    endif

    " check if we have a skip available from the base line
    let skipped = get(b:context_skips, a:line.number, -1)
    if skipped != -1
        let b:context_saved += a:line.number-1 - skipped
        " call s:echof('  skipped', a:line.number, '->', skipped)
        return s:make_line(skipped, indent(skipped), getline(skipped))
    endif

    " if line starts with closing brace or similar: jump to matching
    " opening one and add it to context. also for other prefixes to show
    " the if which belongs to an else etc.
    if s:extend_line(a:line.text)
        let max_indent = a:line.indent " allow same indent
    else
        let max_indent = a:line.indent - 1 " must be strictly less
    endif

    if max_indent < 0
        return s:nil_line
    endif

    " search for line with matching indent
    let current_line = a:line.number - 1
    while 1
        if current_line <= 0
            " nothing found
            return s:nil_line
        endif

        let b:context_cost += 1

        let indent = indent(current_line)
        if indent > max_indent
            " use skip if we have, next line otherwise
            let skipped = get(b:context_skips, current_line, current_line-1)
            let b:context_saved += current_line-1 - skipped
            let current_line = skipped
            continue
        endif

        let line = getline(current_line)
        if s:skip_line(line)
            let current_line -= 1
            continue
        endif

        return s:make_line(current_line, indent, line)
    endwhile
endfunction

" https://vi.stackexchange.com/questions/19056/how-to-create-preview-window-to-display-a-string
function! s:open_preview() abort
    call s:echof('> open_preview')
    let settings = '+setlocal'        .
                \ ' buftype=nofile'   .
                \ ' modifiable'       .
                \ ' nobuflisted'      .
                \ ' nocursorline'     .
                \ ' nonumber'         .
                \ ' norelativenumber' .
                \ ' noswapfile'       .
                \ ' nowrap'           .
                \ ' signcolumn=no'    .
                \ ' \|'                                 .
                \ ' let b:airline_disable_statusline=1' .
                \ ''
    execute 'silent! aboveleft pedit' escape(settings, ' ') s:buffer_name
endfunction

function! s:show_in_preview(lines) abort
    call s:echof('> show_in_preview', len(a:lines))

    call s:close_preview()

    if w:min_height < len(a:lines)
        let w:min_height = len(a:lines)
    endif

    if w:min_height == 0
        " nothing to do
        call s:echof('  none')
        return
    endif

    while len(a:lines) < w:min_height
        call add(a:lines, s:nil_line)
    endwhile

    let syntax  = &syntax
    let tabstop = &tabstop
    let padding = wincol() - virtcol('.')

    let s:log_indent += 2
    call s:open_preview()
    let s:log_indent -= 2

    " try to jump to new preview window
    silent! wincmd P
    if !&previewwindow
        " NOTE: apparently this can fail with E242, see #6
        " in that case just silently abort
        call s:echof('  no preview window')
        return
    endif

    " NOTE: this overwrites a:lines, but we don't need it anymore
    call map(a:lines, function('s:display_line'))
    silent 0put =a:lines " paste lines
    1                    " and jump to first line

    execute 'setlocal syntax='  . syntax
    execute 'setlocal tabstop=' . tabstop
    call s:set_padding(padding)

    " resize window
    execute 'resize' len(a:lines)

    wincmd p " jump back
endfunction

function! s:close_preview() abort
    silent! wincmd P " jump to preview, but don't show error
    if !&previewwindow
        return
    endif
    wincmd p

    if &equalalways
        " NOTE: if 'equalalways' is set (which it is by default) then :pclose
        " will change the window layout. here we try to restore the window
        " layout based on some help from /u/bradagy, see
        " https://www.reddit.com/r/vim/comments/e7l4m1
        set noequalalways
        pclose
        let layout = winrestcmd() | set equalalways | noautocmd execute layout
    else
        pclose
    endif
endfunction

" NOTE: this function updates the statusline too, as it depends on the padding
function! s:set_padding(padding) abort
    let padding = a:padding
    if padding >= 0
        execute 'setlocal foldcolumn=' . padding
        let w:padding = padding
    else
        " padding can be negative if cursor was on the wrapped part of a wrapped line
        " in that case don't try to apply it, but still update the statusline
        " using the last known padding value
        let padding = w:padding
    endif

    let statusline = '%=' . s:buffer_name . ' ' " trailing space for padding
    if s:hidden_line.number > 0
        let statusline = repeat(' ', padding + s:hidden_line.indent) . s:ellipsis . statusline
    endif
    execute 'setlocal statusline=' . escape(statusline, ' ')
endfunction


function! s:join(lines, diff_want) abort
    let diff_want = a:diff_want

    " only works with at least 3 parts, so disable otherwise
    if g:context_max_join_parts < 3
        return [a:lines, a:diff_want]
    endif

    " call s:echof('> join', len(a:lines), diff_want)
    let pending = [] " lines which might be joined with previous
    let joined = a:lines[:0] " start with first line
    for line in a:lines[1:]
        if s:join_line(line.text)
            " add lines without word characters to pending list
            call add(pending, line)
            let diff_want -= 1
            continue
        endif

        " don't join lines with word characters
        " but first join pending lines to previous output line
        let joined[-1] = s:join_pending(joined[-1], pending)
        let pending = []
        call add(joined, line)
    endfor

    " join remaining pending lines to last
    let joined[-1] = s:join_pending(joined[-1], pending)
    return [joined, diff_want]
endfunction

function! s:join_pending(base, pending) abort
    " call s:echof('> join_pending', len(a:pending))
    if len(a:pending) == 0
        return a:base
    endif

    let max = g:context_max_join_parts
    if len(a:pending) > max-1
        call remove(a:pending, (max-1)/2-1, -max/2-1)
        call insert(a:pending, s:nil_line, (max-1)/2-1) " middle marker
    endif

    let joined = a:base
    for line in a:pending
        let joined.text .= ' '
        if line.number == 0
            " this is the middle marker, use long ellipsis
            let joined.text .= s:ellipsis5
        elseif joined.number != 0 && line.number != joined.number + 1
            " not after middle marker and there are lines in between: show ellipsis
            let joined.text .= s:ellipsis . ' '
        endif

        let joined.text .= s:trim(line.text)
        let joined.number = line.number
    endfor

    return joined
endfunction

function! s:limit(lines, diff_want, indent) abort
    " call s:echof('> limit', a:indent, len(a:lines), a:diff_want)
    if a:diff_want <= 0
        return [a:lines, a:diff_want]
    endif

    let max = g:context_max_per_indent
    if len(a:lines) <= max
        return [a:lines, a:diff_want]
    endif

    let diff = len(a:lines) - max
    let diff2 = diff - a:diff_want
    if diff2 > 0
        let max += diff2
    endif

    let limited = a:lines[: max/2-1]
    call add(limited, s:make_line(0, a:indent, repeat(' ', a:indent) . s:ellipsis))
    call extend(limited, a:lines[-(max-1)/2 :])
    return [limited, a:diff_want - (len(a:lines) - max)]
endif
endfunction

function! s:make_line(number, indent, text) abort
    return {
                \ 'number': a:number,
                \ 'indent': a:indent,
                \ 'text':   a:text,
                \ }
endfunction

function! s:display_line(index, line) abort
    return a:line.text

    " NOTE: comment out the line above to include this debug info
    let n = &columns - 25 - strchars(s:trim(a:line.text)) - a:line.indent
    return printf('%s%s // %2d n:%5d i:%2d', a:line.text, repeat(' ', n), a:index+1, a:line.number, a:line.indent)
endfunction

function! s:extend_line(line) abort
    return a:line =~ g:context_extend_regex
endfunction

function! s:skip_line(line) abort
    return a:line =~ g:context_skip_regex
endfunction

function! s:join_line(line) abort
    return a:line =~ g:context_join_regex
endfunction

function s:trim(string) abort
    return substitute(a:string, '^\s*', '', '')
endfunction

" debug logging, set g:context_logfile to activate
function! s:echof(...) abort
    let args = join(a:000)
    let args = substitute(args, "'", '"', 'g')
    let args = substitute(args, '!', '^', 'g')
    let message = repeat(' ', s:log_indent) . args

    " echom message
    if exists('g:context_logfile')
        execute "silent! !echo '" . message . "' >>" g:context_logfile
    endif
endfunction
