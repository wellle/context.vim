let s:context_buffer_name = '<context.vim>'

function! context#popup#update_context() abort
    let [lines, base_line] = context#popup#get_context()
    call context#util#echof('> context#popup#update_context', len(lines))

    let w:context.lines  = lines
    let w:context.indent = g:context.Border_indent(base_line)

    call context#util#show_cursor()
    call s:show()
endfunction

" returns [lines, base_line_nr]
function! context#popup#get_context() abort
    call context#util#echof('context#popup#get_context')
    " NOTE: there's a problem if some of the hidden lines
    " (behind the popup) are wrapped. then our calculations are off
    " TODO: fix that?

    " a skipped line has the same context as the next unskipped one below
    let skipped       =  0
    let line_number   = w:context.cursor_line - 1 " first iteration starts with cursor_line
    let top_line      = w:context.top_line
    let border_height = g:context.show_border

    while 1
        let line_number += 1

        let indent = g:context.Indent(line_number) " -1 for invalid lines
        if indent < 0
            call context#util#echof('negative indent', line_number)
            return [[], 0]
        endif

        let line = getline(line_number) " empty for invalid lines
        if context#line#should_skip(line)
            let skipped += 1
            call context#util#echof('skip', line_number)
            continue
        endif

        let base_line = context#line#make(line_number, indent, line)
        let [context, line_count] = context#context#get(base_line)
        call context#util#echof('context#get', line_number, line_count)

        if line_count == 0
            return [[], 0]
        endif

        if w:context.fix_strategy == 'scroll'
            call context#util#echof('scroll: done')
            break
        endif

        " call context#util#echof('fit?', top_line, line_count, border_height, line_number)
        if top_line + line_count + border_height <= line_number
            " this context fits, use it
            break
        endif

        " try again on next line if this context doesn't fit
        let skipped = 0
    endwhile

    let [lines, line_number] = context#util#filter(context, line_number, 1)

    if g:context.show_border && len(lines) > 0
        call add(lines, '') " add line for border, will be replaced later
    endif

    return [lines, line_number]
endfunction

function! context#popup#layout() abort
    call context#util#echof('> context#popup#layout')

    for winid in keys(g:context.popups)
        let popup = g:context.popups[winid]
        let winbuf = winbufnr(winid)
        let popupbuf = winbufnr(popup)

        if winbuf == -1 || popupbuf == -1
            if popupbuf != -1
                call s:close(popup)
            endif
            call remove(g:context.popups, winid)
            continue
        endif

        call context#util#update_window_state(winid)

        " NOTE: the context might be wrong as the top line might have
        " changed, but we can't really fix that (without temporarily
        " moving the cursor which we'd like to avoid)
        " TODO: fix that?
        call context#popup#redraw(winid)
    endfor
endfunction

function! context#popup#redraw(winid) abort
    let popup = get(g:context.popups, a:winid)
    if popup == 0
        return
    endif

    let c = getwinvar(a:winid, 'context', {})
    if c == {}
        return
    endif

    let lines = c.lines
    if len(lines) == 0
        return
    endif

    if g:context.show_border
        let lines[-1] = s:get_border_line(a:winid, 1)
        let c.lines = lines
    endif

    call context#util#echof('  > context#popup#redraw', len(lines))
    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#redraw(a:winid, popup, lines)
    elseif g:context.presenter == 'vim-popup'
        call context#popup#vim#redraw(a:winid, popup, lines)
    endif

    for i in range(1, len(lines))
        " TODO: seems like we need to handle the case where w:context doesn't
        " exist. do we have a bug somewhere? try open normal.c, split window,
        " change with fzf (probably the fzf popup issue again...)
        let n = 1
        let m = 0

        let d = w:context.sign_width
        if d > 0
            let m += d
            call matchaddpos('SignColumn', [[i,n,m]], 10, -1, {'window': popup})
            let n += m
        endif

        let d = w:context.number_width
        if d > 0
            let m = w:context.number_width
            call matchaddpos('LineNr', [[i,n,m]], 10, -1, {'window': popup})
            let n += m
        endif
    endfor
endfunction

" close all popups
function! context#popup#clear() abort
    for key in keys(g:context.popups)
        call s:close(g:context.popups[key])
    endfor
    let g:context.popups = {}
endfunction

" close current popup
function! context#popup#close() abort
    let winid = win_getid()
    let popup = get(g:context.popups, winid)
    if popup == 0
        return
    endif

    call s:close(popup)
    call remove(g:context.popups, winid)
endfunction

" popup related
function! s:show() abort
    let winid = win_getid()
    let popup = get(g:context.popups, winid)
    let popupbuf = winbufnr(popup)

    if popup > 0 && popupbuf == -1
        let popup = 0
        call remove(g:context.popups, winid)
    endif

    if len(w:context.lines) == 0
        call context#util#echof('  no lines')

        if popup > 0
            call s:close(popup)
            call remove(g:context.popups, winid)
        endif
        return
    endif

    if popup == 0
        let popup = s:open()
        let g:context.popups[winid] = popup
    endif

    call context#popup#redraw(winid)

    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#redraw_screen()
    endif
endfunction

" TODO: consider fold column too

function! s:open() abort
    call context#util#echof('  > open')
    if g:context.presenter == 'nvim-float'
        let popup = context#popup#nvim#open()
    elseif g:context.presenter == 'vim-popup'
        let popup = context#popup#vim#open()
    endif

    " NOTE: we use a non breaking space here again before the buffer name
    let border = ' *' .g:context.char_border . '* '
    let tag = s:context_buffer_name
    " TODO: remove these
    call matchadd(g:context.highlight_border, border, 10, -1, {'window': popup})
    call matchadd(g:context.highlight_tag,    tag,    10, -1, {'window': popup})

    let buf = winbufnr(popup)
    " call setbufvar(buf, '&syntax', &syntax)

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
    let indent = a:indent ? c.indent : 0
    " let indent = 0

    let line_len = c.size_w - c.padding - indent - 1
    if g:context.show_tag
        let line_len -= len(s:context_buffer_name) + 1
    endif

    let line = repeat(' ', w:context.sign_width)

    " number column
    " TODO: remove special handling for 0 again
    if w:context.number_width > 0
        " TODO: show number of hidden lines below last context line
        let n = 0
        let line .= printf('%*d ', w:context.number_width - 1, n)
    endif

    let line .= repeat(' ', indent)
    let line .= repeat(g:context.char_border, line_len)

    " NOTE: we use a non breaking space before the buffer name because there
    " can be some display issues in the Kitty terminal with a normal space
    let line .= ' '

    if g:context.show_tag
        let line .= s:context_buffer_name . ' '
    endif

    return line
endfunction
