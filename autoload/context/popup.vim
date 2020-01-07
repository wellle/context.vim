function! context#popup#get_context() abort
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
        let base_line = context#line#make(line_number, indent, line)

        if base_line.indent < 0
            let lines = []
        elseif context#line#should_skip(line)
            let skipped += 1
            continue
        else
            let lines = context#context#get(base_line)
        endif

        let line_count = len(lines)
        " call context#util#echof('  got', line_offset, line_offset, line_count, skipped)

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
    call map(lines, function('context#line#display'))

    " success, we found a fitting context
    while len(lines) < line_offset - skipped - 1
        call add(lines, '')
    endwhile

    let winid = win_getid()
    let w:context_indent = base_line.indent
    call add(lines, s:get_border_line(winid))
    let w:context_lines = lines " to update border line on padding change
    return lines
endfunction

let s:popups = {}

" popup related
function! context#popup#show(winid, lines) abort
    call context#util#echof('> show_in_popup', len(a:lines))
    let popup = get(s:popups, a:winid)
    let popupbuf = winbufnr(popup)

    if popup > 0 && popupbuf == -1
        let popup = 0
        call remove(s:popups, a:winid)
    endif

    if len(a:lines) == 0
        call context#util#echof('  no lines')
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
        call context#popup#nvim#redraw()
    endif
endfunction

" TODO: reorder functions, after split out to autoload files
function! context#popup#update_layout() abort
    call context#util#echof('> update_layout')

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

        call context#util#update_window_state(winid)

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

function! context#popup#clear() abort
    for key in keys(s:popups)
        call s:popup_close(s:popups[key])
    endfor
    let s:popups = {}
endfunction


function! s:popup_open() abort
    call context#util#echof('  > popup_open')
    if g:context_presenter == 'nvim-float'
        let popup = context#popup#nvim#open()
    elseif g:context_presenter == 'vim-popup'
        let popup = context#popup#vim#open()
    endif

    let border = ' *' .g:context_border_char . '* ' . g:context_buffer_name . ' '
    let tag = g:context_buffer_name
    let m = matchadd(g:context_highlight_border, border, 10, -1, {'window': popup})
    let m = matchadd(g:context_highlight_tag,    tag,    10, -1, {'window': popup})

    let buf = winbufnr(popup)
    call setbufvar(buf, '&syntax', &syntax)

    return popup
endfunction

function! s:popup_update(winid, popup, lines) abort
    call context#util#echof('  > popup_update', len(a:lines))
    if g:context_presenter == 'nvim-float'
        call context#popup#nvim#update(a:winid, a:popup, a:lines)
    elseif g:context_presenter == 'vim-popup'
        call context#popup#vim#update(a:winid, a:popup, a:lines)
    endif
endfunction

function! s:popup_close(popup) abort
    call context#util#echof('  > popup_close')
    if g:context_presenter == 'nvim-float'
        call context#popup#nvim#close(a:popup)
    elseif g:context_presenter == 'vim-popup'
        call context#popup#vim#close(a:popup)
    endif
endfunction

function! s:get_border_line(winid) abort
    let width    = getwinvar(a:winid, 'context_width')
    let indent   = getwinvar(a:winid, 'context_indent')
    let padding  = getwinvar(a:winid, 'context_padding')
    let line_len = width - indent - len(g:context_buffer_name) - 2 - padding

    return ''
                \ . repeat(' ', indent)
                \ . repeat(g:context_border_char, line_len)
                \ . ' '
                \ . g:context_buffer_name
                \ . ' '
endfunction
