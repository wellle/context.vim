let s:context_buffer_name = '<context.vim>'

function! context#popup#update_context() abort
    let [lines, bottom_lines, indent] = context#popup#get_context(w:context.top_line)
    call context#util#echof('> context#popup#update_context', len(lines))
    let w:context.top_lines    = lines
    let w:context.bottom_lines = bottom_lines
    let w:context.indent       = indent
    call s:show()
endfunction

" returns [top_lines, bottom_lines, indent]
function! context#popup#get_context(base_line) abort
    " NOTE: there's a problem if some of the hidden lines
    " (behind the popup) are wrapped. then our calculations are off
    " TODO: fix that?

    " a skipped line has the same context as the next unskipped one below
    let skipped = 0
    let context_count = 0 " how many contexts did we check?
    let line_offset = -1 " first iteration starts with zero
    let bottom_lines = []

    while 1
        let line_offset += 1
        let line_number = a:base_line + line_offset
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
            if len(bottom_lines) == 0
                let bottom_lines = copy(lines)
                call map(bottom_lines, function('context#line#display'))
                call insert(bottom_lines, '') " will be replaced with border line
                let bottom_lines = bottom_lines
            endif
        endif

        let line_count = len(lines)
        " call context#util#echof('  got', line_offset, line_offset, line_count, skipped)

        if line_count == 0 && context_count == 0
            " if we get an empty context on the first non skipped line
            return [[], [], 0]
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

    call add(lines, '') " will be replaced with border line
    return [lines, bottom_lines, base_line.indent]
endfunction

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
        call context#popup#redraw(winid, 1)
    endfor
endfunction

function! context#popup#redraw(winid, force) abort
    let popup = get(s:popups, a:winid)
    if popup == 0
        return
    endif

    let c = getwinvar(a:winid, 'context')
    let lines = c.top_lines
    if len(lines) == 0
        return
    endif

    " check where to put the context, prefer top, but switch to bottom if
    " cursor is too high. abort if popup doesn't have to move and no a:force
    " is given
    if c.cursor_offset >= len(lines) " top
        if !a:force && c.popup_offset == 0
            call context#util#echof('  > context#popup#redraw no force skip top')
            return
        endif

        let lines = c.top_lines
        if len(lines) > 0
            let lines[-1] = s:get_border_line(a:winid, 1)
            let c.top_lines = lines
        endif

        let c.popup_offset = 0
    else " bottom
        if !a:force && c.popup_offset > 0
            call context#util#echof('  > context#popup#redraw no force skip bottom')
            return
        endif

        let lines = c.bottom_lines
        if len(lines) > 0
            let lines[0] = s:get_border_line(a:winid, 0)
            let c.bottom_lines = lines
        endif

        let c.popup_offset = winheight(a:winid) - len(lines)
    endif

    call context#util#echof('  > context#popup#redraw', len(lines))
    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#redraw(a:winid, popup, lines)
    elseif g:context.presenter == 'vim-popup'
        call context#popup#vim#redraw(a:winid, popup, lines)
    endif
endfunction

function! context#popup#clear() abort

    for key in keys(s:popups)
        call s:close(s:popups[key])
    endfor
    let s:popups = {}
endfunction

let s:popups = {}

" popup related
function! s:show() abort
    let winid = win_getid()
    let popup = get(s:popups, winid)
    let popupbuf = winbufnr(popup)

    if popup > 0 && popupbuf == -1
        let popup = 0
        call remove(s:popups, winid)
    endif

    if len(w:context.top_lines) == 0
        call context#util#echof('  no lines')

        " if there are no lines, we reset popup_offset here so we'll try to
        " show the next non empty context at the top again
        let w:context.popup_offset = 0

        if popup > 0
            call s:close(popup)
            call remove(s:popups, winid)
        endif
        return
    endif

    if popup == 0
        let popup = s:open()
        let s:popups[winid] = popup
    endif

    call context#popup#redraw(winid, 1)

    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#redraw_screen()
    endif
endfunction

function! s:open() abort
    call context#util#echof('  > open')
    if g:context.presenter == 'nvim-float'
        let popup = context#popup#nvim#open()
    elseif g:context.presenter == 'vim-popup'
        let popup = context#popup#vim#open()
    endif

    let border = ' *' .g:context.border_char . '* ' . s:context_buffer_name . ' '
    let tag = s:context_buffer_name
    let m = matchadd(g:context.highlight_border, border, 10, -1, {'window': popup})
    let m = matchadd(g:context.highlight_tag,    tag,    10, -1, {'window': popup})

    let buf = winbufnr(popup)
    call setbufvar(buf, '&syntax', &syntax)

    return popup
endfunction

function! s:close(popup) abort
    call context#util#echof('  > close')
    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#close(a:popup)
    elseif g:context.presenter == 'vim-popup'
        call context#popup#vim#close(a:popup)
    endif
endfunction

function! s:get_border_line(winid, indent) abort
    let c = getwinvar(a:winid, 'context')
    let indent  = a:indent ? c.indent : 0

    let line_len = c.width - indent - len(s:context_buffer_name) - 2 - c.padding
    return ''
                \ . repeat(' ', indent)
                \ . repeat(g:context.border_char, line_len)
                \ . ' '
                \ . s:context_buffer_name
                \ . ' '
endfunction
