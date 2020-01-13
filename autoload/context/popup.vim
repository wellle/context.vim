let s:context_buffer_name = '<context.vim>'

function! context#popup#get_context() abort
    " NOTE: there's a problem if some of the hidden lines (behind the
    " popup) are wrapped. then our calculations are off
    " TODO: fix that?

    " a skipped line has the same context as the next unskipped one below
    let skipped = 0
    let context_count = 0 " how many contexts did we check?
    let line_offset = -1 " first iteration starts with zero
    let winid = win_getid()
    let w:context_bottom_lines = []

    while 1
        let line_offset += 1
        let line_number = w:context_top_line + line_offset
        let indent = indent(line_number) "    -1 for invalid lines
        let line = getline(line_number)  " empty for invalid lines
        let base_line = context#line#make(line_number, indent, line)

        if base_line.indent < 0
            let lines = []
        elseif context#line#should_skip(line)
            let skipped += 1
            continue
        else
            let lines = context#context#get(base_line)
            if len(w:context_bottom_lines) == 0
                let bottom_lines = copy(lines)
                call map(bottom_lines, function('context#line#display'))
                call insert(bottom_lines, '') " will be replaced with border line
                let w:context_bottom_lines = bottom_lines
            endif
        endif

        let line_count = len(lines)
        " call context#util#echof('  got', line_offset, line_offset, line_count, skipped)

        if line_count == 0 && context_count == 0
            " if we get an empty context on the first non skipped line
            let w:context_top_lines = []
            return
        endif
        let context_count += 1

        if line_count < line_offset
            break
        endif

        " try again on next line if this context doesn't fit
        let skipped = 0
    endwhile

    " NOTE: this overwrites lines, from here on out it's just a list of string
    call map(lines, function('context#line#display'))

    " success, we found a fitting context
    while len(lines) < line_offset - skipped - 1
        call add(lines, '')
    endwhile

    let w:context_indent = base_line.indent
    call add(lines, '') " will be replaced with border line
    let w:context_top_lines = lines " to update border line on padding change
endfunction

let s:popups = {}

" popup related
" TODO: merge with above
function! context#popup#show(winid) abort
    let line_count = len(w:context_top_lines)
    call context#util#echof('> context#popup#show', line_count)
    let popup = get(s:popups, a:winid)
    let popupbuf = winbufnr(popup)

    if popup > 0 && popupbuf == -1
        let popup = 0
        call remove(s:popups, a:winid)
    endif

    " TODO: what about this idea? seems to work and is simple, but has some
    " annoying behaviors when scrolling...
    " call setwinvar(a:winid, '&scrolloff', len(w:context_top_lines))

    if line_count == 0
        call context#util#echof('  no lines')
        if popup > 0
            call s:close(popup)
            call remove(s:popups, a:winid)
        endif
        return
    endif

    if popup == 0
        let popup = s:open()
        let s:popups[a:winid] = popup
    endif

    call s:update(a:winid, popup, 1)

    if g:context_presenter == 'nvim-float'
        call context#popup#nvim#redraw()
    endif
endfunction

" TODO: reorder functions, after split out to autoload files
function! context#popup#layout() abort
    call context#util#echof('> context#popup#layout')

    for winid in keys(s:popups)
        let popup = s:popups[winid]
        let winbuf = winbufnr(winid)
        let popupbuf = winbufnr(popup)

        if winbuf == -1 || popupbuf == -1
            if popupbuf != -1
                call s:close(popup)
            endif
            call remove(s:popups, winid)
            continue
        endif

        call context#util#update_window_state(winid)

        " NOTE: the context might be wrong as the top line might have
        " changed, but we can't really fix that (without temporarily
        " moving the cursor which we'd like to avoid)
        " TODO: fix that?
        call s:update(winid, popup, 1)
    endfor
endfunction

" TODO: remove?
" probably yes, stop injecting popup into s:update and rename that
" function, then can inline this one
function! context#popup#move(winid) abort
    call context#util#echof('> context#popup#move')
    let popup = get(s:popups, a:winid, -1)
    if popup == -1
        return
    endif

    " NOTE: don't force update here, only if we switched between top and
    " bottom
    call s:update(a:winid, popup, 0)
endfunction

function! context#popup#clear() abort

    for key in keys(s:popups)
        call s:close(s:popups[key])
    endfor
    let s:popups = {}
endfunction


function! s:open() abort
    call context#util#echof('  > popup_open')
    if g:context_presenter == 'nvim-float'
        let popup = context#popup#nvim#open()
    elseif g:context_presenter == 'vim-popup'
        let popup = context#popup#vim#open()
    endif

    let border = ' *' .g:context_border_char . '* ' . s:context_buffer_name . ' '
    let tag = s:context_buffer_name
    let m = matchadd(g:context_highlight_border, border, 10, -1, {'window': popup})
    let m = matchadd(g:context_highlight_tag,    tag,    10, -1, {'window': popup})

    let buf = winbufnr(popup)
    call setbufvar(buf, '&syntax', &syntax)

    return popup
endfunction

function! s:update(winid, popup, force) abort
    let lines = copy(getwinvar(a:winid, 'context_top_lines'))
    if len(lines) == 0
        return
    endif

    " TODO: need this check?
    if !a:force
        let last_offset = getwinvar(a:winid, 'context_popup_offset')
    endif

    " TODO: this should only affect the active window, not others!
    " TODO: map H and zt to not switch to bottom context?
    " TODO: minor: can we move this logic into update_state to avoid logs if no
    " update is needed?
    " TODO: can we simplify this?
    if getwinvar(a:winid, 'context_cursor_offset') >= len(lines) " top
        if !a:force && last_offset == 0
            call context#util#echof('  > popup_update no force skip top')
            return
        endif

        let lines = getwinvar(a:winid, 'context_top_lines')

        if len(lines) > 0
            let lines[-1] = s:get_border_line(a:winid, 1)
            call setwinvar(a:winid, 'context_top_lines', lines)
        endif

        call setwinvar(a:winid, 'context_popup_offset', 0)
    else " bottom
        if !a:force && last_offset > 0
            call context#util#echof('  > popup_update no force skip bottom')
            return
        endif

        let lines = copy(getwinvar(a:winid, 'context_bottom_lines'))
        " TODO: need this check?
        if len(lines) == 0
            " return
        endif

        let lines = getwinvar(a:winid, 'context_bottom_lines')
        if len(lines) > 0
            let lines[0] = s:get_border_line(a:winid, 0)
            call setwinvar(a:winid, 'context_bottom_lines', lines)
        endif

        call setwinvar(a:winid, 'context_popup_offset', winheight(a:winid) - len(lines))
    endif


    " TODO: avoid update if we didn't switch between top and bottom
    " as will often be the case when scrolling

    call context#util#echof('  > popup_update', len(lines))
    if g:context_presenter == 'nvim-float'
        call context#popup#nvim#update(a:winid, a:popup, lines)
    elseif g:context_presenter == 'vim-popup'
        call context#popup#vim#update(a:winid, a:popup, lines)
    endif
endfunction

function! s:close(popup) abort
    call context#util#echof('  > popup_close')
    if g:context_presenter == 'nvim-float'
        call context#popup#nvim#close(a:popup)
    elseif g:context_presenter == 'vim-popup'
        call context#popup#vim#close(a:popup)
    endif
endfunction

function! s:get_border_line(winid, indent) abort
    let width   =            getwinvar(a:winid, 'context_width')
    let padding =            getwinvar(a:winid, 'context_padding')
    let indent  = a:indent ? getwinvar(a:winid, 'context_indent') : 0

    let line_len = width - indent - len(s:context_buffer_name) - 2 - padding
    return ''
                \ . repeat(' ', indent)
                \ . repeat(g:context_border_char, line_len)
                \ . ' '
                \ . s:context_buffer_name
                \ . ' '
endfunction
