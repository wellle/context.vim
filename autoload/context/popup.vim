function! context#popup#update_context() abort
    let [lines, base_line] = context#popup#get_context()
    call context#util#echof('> context#popup#update_context', len(lines))

    " NOTE: we remember context lines and baseline indent per window so we can
    " redraw them in #layout when the window layout changes
    let w:context.lines = lines
    let [w:context.level, w:context.indent] = g:context.Border_indent(base_line)

    call s:show_cursor()
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

        let [level, indent] = g:context.Indent(line_number) " -1 for invalid lines
        if indent < 0
            call context#util#echof('negative indent', line_number)
            return [[], 0]
        endif

        let text = getline(line_number) " empty for invalid lines
        if context#line#should_skip(text)
            let skipped += 1
            " call context#util#echof('skip', line_number)
            continue
        endif

        let base_line = context#line#make(line_number, level, indent, text)
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
    call context#util#echof('> context#popup#redraw', a:winid, popup)

    if popup == 0
        return
    endif

    let c = getwinvar(a:winid, 'context', {})
    if c == {}
        return
    endif

    if len(c.lines) == 0
        return
    endif

    call context#util#echof('  > context#popup#redraw', len(c.lines))

    let display_lines = []
    let hls = [] " list of lists, one per context line
    for line in c.lines
        let [text, highlights] = context#line#display(a:winid, line)
        call add(display_lines, text)
        call add(hls, highlights)
    endfor

    if g:context.show_border
        let border_line = context#util#get_border_line(c.lines, w:context.level, w:context.indent, a:winid)
        let [text, highlights] = context#line#display(a:winid, border_line)
        call add(display_lines, text)
        call add(hls, highlights)
    endif

    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#redraw(a:winid, popup, display_lines)
    elseif g:context.presenter == 'vim-popup'
        call context#popup#vim#redraw(a:winid, popup, display_lines)
    endif

    let args = {'window': popup}
    for h in range(0, len(hls)-1)
        for hl in hls[h]
            call matchaddpos(hl[0], [[h+1, hl[1]+1, hl[2]]], 10, -1, args)
        endfor
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

function! s:show_cursor() abort
    if len(w:context.lines) == 0
        return
    endif

    " compare height of context to cursor line on screen
    let n = len(w:context.lines) + g:context.show_border - (w:context.cursor_line - w:context.top_line)
    if n <= 0
        " if cursor is low enough, nothing to do
        return
    end

    " otherwise we have to either move or scroll the cursor accordingly
    " call context#util#echof('show_cursor', w:context.fix_strategy, n)
    let key = (w:context.fix_strategy == 'move') ? 'j' : "\<C-Y>"
    execute 'normal! ' . n . key
    call context#util#update_line_state()
endfunction

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

function! s:open() abort
    call context#util#echof('  > open')
    if g:context.presenter == 'nvim-float'
        return context#popup#nvim#open()
    elseif g:context.presenter == 'vim-popup'
        return context#popup#vim#open()
    endif
endfunction

function! s:close(popup) abort
    call context#util#echof('  > close')
    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#close(a:popup)
    elseif g:context.presenter == 'vim-popup'
        call context#popup#vim#close(a:popup)
    endif
endfunction
