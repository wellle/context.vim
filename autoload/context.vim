" TODO: don't hide cursor, hide (partially) context instead, hint that it's
" partial?
" TODO: reorder functions and split out into autoload dirs

" consts
let s:buffer_name = '<context.vim>'

" cached
let s:ellipsis  = repeat(g:context_ellipsis_char, 3)
let s:ellipsis5 = repeat(g:context_ellipsis_char, 5)
let s:nil_line  = {'number': 0, 'indent': 0, 'text': ''}

" state
" NOTE: there's more state in window local w: variables
let s:activated     = 0
let s:ignore_update = 0
let s:log_indent    = 0
let s:popups        = {}
let s:wincount      = 0


" call this on VimEnter to activate the plugin
function! context#activate() abort
    " for some reason there seems to be a race when we try to show context of
    " one buffer before another one gets opened in startup
    " to avoid that we wait for startup to be finished
    let s:activated = 1
    call context#update(0, 'activate')
endfunction

function! context#enable() abort
    let g:context_enabled = 1
    call context#update(1, 'enable')
endfunction

function! context#disable() abort
    call s:popup_clear()
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


function! context#update(force_resize, source) abort
    if 0
                \ || !g:context_enabled
                \ || !s:activated
                \ || s:ignore_update
                \ || &previewwindow
                \ || mode() != 'n'
        return
    endif

    let s:ignore_update = 1

    let winid = win_getid()

    let w:context_needs_update = a:force_resize
    let w:context_needs_layout = a:force_resize
    call s:update_state()
    call s:update_window_state(winid)

    if w:context_needs_update || w:context_needs_layout
        call s:echof()
    endif

    if w:context_needs_update
        call s:update_context(winid, 1, a:force_resize, a:source)
    endif

    if w:context_needs_layout
        call s:update_layout()
    endif

    let w:context_needs_update = 0
    let w:context_needs_layout = 0

    let s:ignore_update = 0
endfunction

function! context#clear_cache() abort
    call context#update(0, 'clear_cache')
endfunction

function! context#cache_stats() abort
    let skips = len(b:context_skips)
    let cost  = b:context_cost
    let total = b:context_cost + b:context_saved
    echom printf('cache: %d skips, %d / %d (%.1f%%)', skips, cost, total, 100.0 * cost / total)
endfunction

" TODO: reorder functions, after split out to autoload files
function! s:update_layout() abort
    if g:context_presenter == 'preview'
        return
    endif

    call s:echof('> update_layout')

    for winid in keys(s:popups)
        let popup = s:popups[winid]
        let winbuf = winbufnr(winid)
        let popupbuf = winbufnr(popup)

        if winbuf == -1 || popupbuf == -1
            if popupbuf != -1
                call s:popup_close(popup)
            endif
            call remove(s:popups, winid)
            continue
        endif

        call s:update_window_state(winid)

        " NOTE: the context might be wrong as the top line might have
        " changed, but we can't really fix that (without temporarily
        " moving the cursor which we'd like to avoid)
        " TODO: fix that?
        let lines = getwinvar(winid, 'context_lines')
        if len(lines) > 0
            let lines[-1] = s:get_border_line(winid)
        endif

        call s:popup_update(winid, popup, lines)
    endfor
endfunction

" NOTE: winid is injected, but will always be current window
" TODO: remove allow_resize, force_resize?
function! s:update_context(winid, allow_resize, force_resize, source) abort
    call s:echof('> update_context', a:source, a:winid, w:context_top_line)
    let s:log_indent += 2

    let popup = get(s:popups, a:winid)

    let base_line = s:get_base_line()
    if g:context_presenter == 'preview'
        let min_height = s:get_min_height_for_preview(a:allow_resize, a:force_resize)
        let lines = s:get_context_for_preview(base_line, min_height)
    else
        let lines = s:get_context_for_popup(a:winid)
        let w:context_lines = lines " to update border line on padding change
    endif

    " TODO: remove
    if len(lines) > 0
        let lines[0] .= ' // winid ' . a:winid
    endif

    if g:context_presenter == 'preview'
        call s:show_in_preview(lines)
    else
        call s:show_in_popup(a:winid, lines)
    endif

    if g:context_presenter == 'preview'
        " call again until it stabilizes
        call s:update_state()
        if w:context_needs_update
            let w:context_needs_update = 0
            call s:update_context(a:winid, 0, 0, 'recurse')
        endif
    endif

    let s:log_indent -= 2
endfunction

" find first line above (hidden) which isn't empty
" return its indent, -1 if no such line
" TODO: this is expensive now, maybe not do it like this? or limit it somehow?
function! s:get_hidden_indent_for_preview(base_line, lines) abort
    call s:echof('> get_hidden_indent_for_preview', a:base_line.number, len(a:lines))
    if len(a:lines) == 0
        " don't show ellipsis if context is empty
        return -1
    endif

    let min_indent = -1
    let max_line = a:lines[-1].number
    let current_line = a:base_line.number - 1 " first hidden line
    while current_line > max_line
        let line = getline(current_line)
        if s:skip_line(line)
            let current_line -= 1
            continue
        endif

        let indent = indent(current_line)
        if min_indent == -1 || min_indent > indent
            let min_indent = indent
        endif

        let current_line -= 1
    endwhile

    return min_indent
endfunction

" find line downwards (from top line) which isn't empty
function! s:get_base_line() abort
    let current_line = w:context_top_line
    while 1
        let indent = indent(current_line)
        if indent < 0 " invalid line
            return s:nil_line
        endif

        let line = getline(current_line)
        if s:skip_line(line)
            let current_line += 1
            continue
        endif

        return s:make_line(current_line, indent, line)
    endwhile
endfunction

function! s:get_context_for_popup(winid) abort
    " NOTE: there's a problem if some of the hidden lines (behind the
    " popup) are wrapped. then our calculations are off
    " TODO: fix that?

    " a skipped line has the same context as the next unskipped one below
    let skipped = 0
    let context_count = 0 " how many contexts did we check?
    let line_offset = -1 " first iteration starts with zero

    while 1
        let line_offset += 1
        let line_number = w:context_top_line + line_offset
        let indent = indent(line_number) "    -1 for invalid lines
        let line = getline(line_number)  " empty for invalid lines
        let base_line = s:make_line(line_number, indent, line)

        if base_line.indent < 0
            let lines = []
        elseif s:skip_line(line)
            let skipped += 1
            continue
        else
            let lines = s:get_context(base_line)
        endif

        let line_count = len(lines)
        " call s:echof('  got', line_offset, line_offset, line_count, skipped)

        if line_count == 0 && context_count == 0
            " if we get an empty context on the first non skipped line
            return []
        endif
        let context_count += 1

        if line_count < line_offset
            break
        endif

        " try again on next line if this context doesn't fit
        let skipped = 0
    endwhile

    " NOTE: this overwrites lines, from here on out it's just a list of string
    call map(lines, function('s:display_line'))

    " success, we found a fitting context
    while len(lines) < line_offset - skipped - 1
        call add(lines, '')
    endwhile

    let w:context_indent = base_line.indent
    call add(lines, s:get_border_line(a:winid))
    return lines
endfunction

function! s:get_context_for_preview(base_line, min_height) abort
    let lines = s:get_context(a:base_line)
    let s:hidden_indent = s:get_hidden_indent_for_preview(a:base_line, lines)

    " NOTE: this overwrites lines, from here on out it's just a list of string
    call map(lines, function('s:display_line'))

    while len(lines) < a:min_height
        call add(lines, '')
    endwhile
    let w:context_min_height = len(lines)

    return lines
endfunction

function! s:get_min_height_for_preview(allow_resize, force_resize) abort
    " adjust min window height based on scroll amount
    if a:force_resize || !exists('w:context_min_height')
        return 0
    endif

    if !a:allow_resize || w:context_scroll_offset == 0
        return w:context_min_height
    endif

    if !exists('w:context_resize_level')
        let w:context_resize_level = 0 " for decreasing window height based on scrolling
    endif

    let diff = abs(w:context_scroll_offset)
    if diff == 1
        " slowly decrease min height if moving line by line
        let w:context_resize_level += g:context_resize_linewise
    else
        " quicker if moving multiple lines (^U/^D: decrease by one line)
        let w:context_resize_level += g:context_resize_scroll / &scroll * diff
    endif

    let t = float2nr(w:context_resize_level)
    let w:context_resize_level -= t
    return w:context_min_height - t
endfunction

" collect all context lines
function! s:get_context(line) abort
    let base_line = a:line
    if base_line.number == 0
        return []
    endif

    let context = {}

    if get(b:, 'context_tick') != b:changedtick
        let b:context_tick  = b:changedtick
        " this dictionary maps a line to its next context line
        " so it allows us to skip large portions of the buffer instead of always
        " having to scan through all of it
        let b:context_skips = {}
        let b:context_cost  = 0
        let b:context_saved = 0
    endif

    while 1
        let context_line = s:get_context_line(base_line)
        let b:context_skips[base_line.number] = context_line.number " cache this lookup

        if context_line.number == 0
            break
        endif

        let indent = context_line.indent
        if !has_key(context, indent)
            let context[indent] = []
        endif

        call insert(context[indent], context_line, 0)

        " for next iteration
        let base_line = context_line
    endwhile

    " join, limit and get context lines
    let lines = []
    for indent in sort(keys(context), 'N')
        let context[indent] = s:join(context[indent])
        let context[indent] = s:limit(context[indent], indent)
        call extend(lines, context[indent])
    endfor

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

    return lines
endfunction

function! s:get_context_line(line) abort
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

function! s:get_border_line(winid) abort
    let width    = getwinvar(a:winid, 'context_width')
    let indent   = getwinvar(a:winid, 'context_indent')
    let padding  = getwinvar(a:winid, 'context_padding')
    let line_len = width - indent - len(s:buffer_name) - 2 - padding

    return ''
                \ . repeat(' ', indent)
                \ . repeat(g:context_border_char, line_len)
                \ . ' '
                \ . s:buffer_name
                \ . ' '
endfunction

function! s:show_in_preview(lines) abort
    call s:echof('> show_in_preview', len(a:lines))

    call s:close_preview()

    if len(a:lines) == 0
        " nothing to do
        call s:echof('  none')
        return
    endif

    let syntax  = &syntax
    let tabstop = &tabstop
    let padding = w:context_padding

    execute 'silent! aboveleft pedit' s:buffer_name

    " try to jump to new preview window
    silent! wincmd P
    if !&previewwindow
        " NOTE: apparently this can fail with E242, see #6
        " in that case just silently abort
        call s:echof('  no preview window')
        return
    endif

    silent 0put =a:lines " paste lines
    1                    " and jump to first line

    setlocal buftype=nofile
    setlocal modifiable
    setlocal nobuflisted
    setlocal nocursorline
    setlocal nonumber
    setlocal norelativenumber
    setlocal noswapfile
    setlocal nowrap
    setlocal signcolumn=no
    execute 'setlocal syntax='  . syntax
    execute 'setlocal tabstop=' . tabstop
    let b:airline_disable_statusline=1
    call s:set_padding_in_preview(padding)

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

function! s:update_state() abort
    let wincount = winnr('$')
    if s:wincount != wincount
        let s:wincount = wincount
        let w:context_needs_layout = 1
    endif

    let top_line = line('w0')
    let last_top_line = get(w:, 'context_top_line', 0)
    if last_top_line != top_line
        let w:context_top_line = top_line
        let w:context_needs_update = 1
    endif
    " used in preview only
    let w:context_scroll_offset = last_top_line - top_line

    " padding can only be checked for the current window
    let padding = wincol() - virtcol('.')
    if padding < 0
        " padding can be negative if cursor was on the wrapped part of a
        " wrapped line in that case don't take the new value
        " in this case we don't want to trigger an update, but still set
        " padding to a value
        if !exists('w:context_padding')
            let w:context_padding = 0
        endif
    elseif get(w:, 'context_padding', -1) != padding
        let w:context_padding = padding
        let w:context_needs_update = 1
    endif
endfunction

function! s:update_window_state(winid) abort
    let width = winwidth(a:winid)
    if getwinvar(a:winid, 'context_width') != width
        call setwinvar(a:winid, 'context_width', width)
        call setwinvar(a:winid, 'context_needs_layout', 1)
    endif

    let height = winheight(a:winid)
    if getwinvar(a:winid, 'context_height') != height
        call setwinvar(a:winid, 'context_height', height)
        call setwinvar(a:winid, 'context_needs_layout', 1)
    endif

    if g:context_presenter != 'preview'
        let screenpos = win_screenpos(a:winid)
        if getwinvar(a:winid, 'context_screenpos', []) != screenpos
            call setwinvar(a:winid, 'context_screenpos', screenpos)
            call setwinvar(a:winid, 'context_needs_layout', 1)
        endif
    endif
endfunction

" NOTE: this function updates the statusline too, as it depends on the padding
function! s:set_padding_in_preview(padding) abort
    execute 'setlocal foldcolumn=' . a:padding

    let statusline = '%=' . s:buffer_name . ' ' " trailing space for padding
    if s:hidden_indent >= 0
        let statusline = repeat(' ', a:padding + s:hidden_indent) . s:ellipsis . statusline
    endif
    execute 'setlocal statusline=' . escape(statusline, ' ')
endfunction


" popup related
function! s:show_in_popup(winid, lines) abort
    call s:echof('> show_in_popup', len(a:lines))
    let popup = get(s:popups, a:winid)
    let popupbuf = winbufnr(popup)

    if popup > 0 && popupbuf == -1
        let popup = 0
        call remove(s:popups, a:winid)
    endif

    if len(a:lines) == 0
        call s:echof('  no lines')
        if popup > 0
            call s:popup_close(popup)
            call remove(s:popups, a:winid)
        endif
        return
    endif

    if popup == 0
        let popup = s:popup_open()
        let s:popups[a:winid] = popup
    endif

    call s:popup_update(a:winid, popup, a:lines)

    if g:context_presenter == 'nvim-float'
        " NOTE: this redraws the screen. this is needed because there's
        " a redraw issue: https://github.com/neovim/neovim/issues/11597
        " TODO: remove this once that issue has been resolved
        " for some reason sometimes it's not enough to :mode without :redraw
        " we do it here because it's not needed for when we call
        " popup_update from update_layout
        redraw
        mode
    endif
endfunction

function! s:popup_open() abort
    call s:echof('  > popup_open')
    if g:context_presenter == 'nvim-float'
        let popup = s:nvim_open_popup()
    elseif g:context_presenter == 'vim-popup'
        let popup = s:vim_open_popup()
    endif

    let border = ' *' .g:context_border_char . '* ' . s:buffer_name . ' '
    let tag = s:buffer_name
    let m = matchadd(g:context_highlight_border, border, 10, -1, {'window': popup})
    let m = matchadd(g:context_highlight_tag,    tag,    10, -1, {'window': popup})

    let buf = winbufnr(popup)
    call setbufvar(buf, '&syntax', &syntax)

    return popup
endfunction

function! s:popup_update(winid, popup, lines) abort
    call s:echof('  > popup_update', len(a:lines))
    if g:context_presenter == 'nvim-float'
        call s:nvim_update_popup(a:winid, a:popup, a:lines)
    elseif g:context_presenter == 'vim-popup'
        call s:vim_update_popup(a:winid, a:popup, a:lines)
    endif
endfunction

function! s:popup_close(popup) abort
    call s:echof('  > popup_close')
    if g:context_presenter == 'nvim-float'
        call nvim_win_close(a:popup, v:true)
    elseif g:context_presenter == 'vim-popup'
        call popup_close(a:popup)
    endif
endfunction

function! s:popup_clear() abort
    for key in keys(s:popups)
        call s:popup_close(s:popups[key])
    endfor
    let s:popups = {}
endfunction

function! s:nvim_open_popup() abort
    call s:echof('    > nvim_open_popup')

    let buf = nvim_create_buf(v:false, v:true)
    let popup = nvim_open_win(buf, 0, {
                \ 'relative':  'win',
                \ 'width':     1,
                \ 'height':    1,
                \ 'col':       0,
                \ 'row':       0,
                \ 'focusable': v:false,
                \ 'anchor':    'NW',
                \ 'style':     'minimal',
                \ })

	call setwinvar(popup, '&winhighlight', 'Normal:' . g:context_highlight_normal)
    call setwinvar(popup, '&wrap', 0)

    return popup
endfunction

function! s:nvim_update_popup(winid, popup, lines) abort
    call s:echof('    > nvim_update_popup', len(a:lines))

    let width   = getwinvar(a:winid, 'context_width')
    let padding = getwinvar(a:winid, 'context_padding')
    let buf     = winbufnr(a:popup)

    call nvim_buf_set_lines(buf, 0, -1, v:true, a:lines)
    call nvim_win_set_config(a:popup, {
                \ 'height': len(a:lines),
                \ 'width':  width,
                \ })

    call setwinvar(a:popup, '&foldcolumn', padding)
endfunction

function! s:vim_open_popup() abort
    call s:echof('    > vim_open_popup')

    " NOTE: popups don't move automatically when windows get resized
    let popup = popup_create('', {
                \ 'wrap':     v:false,
                \ 'fixed':    v:true,
                \ })

	call setwinvar(popup, '&wincolor', g:context_highlight_normal)
    call setwinvar(popup, '&tabstop', &tabstop)

    return popup
endfunction

function! s:vim_update_popup(winid, popup, lines) abort
    call s:echof('    > vim_update_popup', len(a:lines))
    call popup_settext(a:popup, a:lines)

    let width   = getwinvar(a:winid, 'context_width')
    let padding = getwinvar(a:winid, 'context_padding')

    let [line, col] = getwinvar(a:winid, 'context_screenpos')
    call popup_move(a:popup, {
                \ 'line':     line,
                \ 'col':      col,
                \ 'minwidth': width,
                \ 'maxwidth': width,
                \ })

	call win_execute(a:popup, 'set foldcolumn=' . padding)
endfunction



" utility functions

function! s:join(lines) abort
    " only works with at least 3 parts, so disable otherwise
    if g:context_max_join_parts < 3
        return a:lines
    endif

    " call s:echof('> join', len(a:lines))
    let pending = [] " lines which might be joined with previous
    let joined = a:lines[:0] " start with first line
    for line in a:lines[1:]
        if s:join_line(line.text)
            " add lines without word characters to pending list
            call add(pending, line)
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
    return joined
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

function! s:limit(lines, indent) abort
    " call s:echof('> limit', a:indent, len(a:lines))

    let max = g:context_max_per_indent
    if len(a:lines) <= max
        return a:lines
    endif

    let diff = len(a:lines) - max

    let limited = a:lines[: max/2-1]
    call add(limited, s:make_line(0, a:indent, repeat(' ', a:indent) . s:ellipsis))
    call extend(limited, a:lines[-(max-1)/2 :])
    return limited
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

let layout = winrestcmd() | set equalalways | noautocmd execute layout
let padding = wincol() - virtcol('.')
