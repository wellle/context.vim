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
    let context_count =  0 " how many contexts did we check?
    let line_number   = w:context.cursor_line - 1 " first iteration starts with cursor_line
    let top_line      = w:context.top_line
    let border_height = g:context.show_border

    while 1
        let line_number += 1

        let indent = g:context.Indent(line_number) "    -1 for invalid lines
        let line = getline(line_number)            " empty for invalid lines
        let base_line = context#line#make(line_number, indent, line)

        if base_line.indent < 0
            call context#util#echof('negative indent', base_line.number)
            return [[], 0]
        elseif context#line#should_skip(line)
            let skipped += 1
            call context#util#echof('skip', base_line.number)
            continue
        else
            let [context, line_count] = context#context#get(base_line)
            call context#util#echof('context#get', base_line.number, len(context))
        endif

        call context#util#echof('got', top_line, line_number, line_count, border_height, skipped)
        if line_count == 0 && context_count == 0
            " if we get an empty context on the first non skipped line
            return [[], 0]
        endif
        let context_count += 1

        " TODO: as for H, we probably need to change behavior. before this
        " branch we the context would be indepedent of the cursor position
        " within the buffer, so H would not change it. now that it depends on
        " the cursor position H is misleading for now, as it currently picks
        " the highest visible line which can be selected so that the context
        " still fits. but that might not be the highest visible bufferline
        " (below the context) before. I think the expectation would be that H
        " jumps to the highest visible line and if the context gets bigger by
        " that, then the line would need to be scrolled down until the full
        " context fits. or maybe not?
        if w:context.fix_strategy == 'scroll' " && line_number >= w:context.cursor_line
            call context#util#echof('scroll: done')
            break
        endif

        " call context#util#echof('fit?', top_line, line_count, border_height, line_number)
        if top_line + line_count + border_height <= line_number
            " this context fits, use it
            break
        endif

        " if w:context.fix_strategy == 'scroll' && line_number >= w:context.cursor_line
        "     " if we want to show the cursor by scrolling and we reached the
        "     " cursor line, we don't need to check lower lines because the
        "     " cursor line will be visible, so this is the proper context
        "     call context#util#echof('skip cursor line')
        "     break
        " endif

        " try again on next line if this context doesn't fit
        let skipped = 0
    endwhile

    " TODO: test this again, looks like it would be broken now
    if context_count == 0
        " we got here because we ran into the cursor line before we found any
        " context. now we need to scan upwards (from above top line) until we
        " find a line with a context and use that one.

        let skipped     = 0
        let line_offset = 0 " first iteration starts with -1

        while 1
            let line_offset -= 1
            let line_number = w:context.cursor_line + line_offset
            let indent = g:context.Indent(line_number) "    -1 for invalid lines
            let line = getline(line_number)            " empty for invalid lines
            let base_line = context#line#make(line_number, indent, line)

            call context#util#echof('checking above', line_offset, line_number)

            if base_line.indent < 0
                let lines = []
                call context#util#echof('reached nan')
            elseif context#line#should_skip(line)
                let skipped += 1
                continue
            else
                let lines = context#context#get(base_line)
                call context#util#echof('got', len(lines))
            endif

            break
        endwhile
    endif

    " TODO: there's an issue where context lines are hidden when scrolling
    " with <C-E>

    " TODO: extract this big thing as a function? also compare again with
    " preview code, they are very very similar now. maybe something can be
    " extracted

    let max_height = g:context.max_height
    let max_height_per_indent = g:context.max_per_indent

    let height = 0
    let done = 0
    let out = [] " TODO: rename to lines eventually?
    for per_indent in context
        " TODO: merge this check into display() once it works? actually probably not
        " call context#util#echof('per_indent first', per_indent[0].number, w:context.top_line, len(out))

        if done
            break
        endif

        let inner_out = []
        for join_batch in per_indent
            if done
                break
            endif

            if join_batch[0].number >= w:context.top_line + height
                let line_number = join_batch[0].number
                let done = 1
                break
            endif

            for i in range(1, len(join_batch)-1)
                " call context#util#echof('join_batch ', i, join_batch[0].number, w:context.top_line, len(out))
                if join_batch[i].number > w:context.top_line + height + 1
                    let line_number = join_batch[i].number
                    let done = 1
                    call remove(join_batch, i, -1)
                    break " inner loop
                endif
            endfor

            let line = context#line#join(join_batch)
            " call context#util#echof('adding', line)
            if height == 0 && g:context.show_border
                let height += 2 " adding border line
            elseif height < max_height && len(inner_out) < max_height_per_indent
                let height += 1
            endif
            call add(inner_out, line)
        endfor

        " TODO: need another break in this loop if inner for loop break'ed?
        " maybe check height in this level (above inner loop to break)
        
        " TODO: extract function (used in preview too)
        " apply max per indent
        if len(inner_out) <= max_height_per_indent
            call extend(out, inner_out)
            continue
        endif

        let diff = len(inner_out) - max_height_per_indent

        let indent = inner_out[0].indent
        let limited = inner_out[: max_height_per_indent/2-1]
        let ellipsis_line = context#line#make(0, indent, repeat(' ', indent) . g:context.ellipsis)
        call add(limited, ellipsis_line)
        call extend(limited, inner_out[-(max_height_per_indent-1)/2 :])

        call extend(out, limited)
        " TODO: context can actually be empty at this point, handle that
        " (don't show border line)
    endfor

    if len(out) == 0
        return [[], 0]
    endif

    " TODO: extract function (used in preview too)
    " apply total limit
    if len(out) > max_height
        let indent1 = out[max_height/2].indent
        let indent2 = out[-(max_height-1)/2].indent
        let ellipsis = repeat(g:context.char_ellipsis, max([indent2 - indent1, 3]))
        " TODO: test this
        let ellipsis_line = context#line#make(0, indent1, repeat(' ', indent1) . ellipsis)
        call remove(out, max_height/2, -(max_height+1)/2)
        call insert(out, ellipsis_line, max_height/2)
    endif

    if g:context.show_border
        call add(out, context#line#make(0, 0, '')) " add line for border, will be replaced later
    endif

    call map(out, function('context#line#text'))

    return [out, line_number]
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
        call context#popup#redraw(winid, 1)
    endfor
endfunction

function! context#popup#redraw(winid, force) abort
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

    " check where to put the context, prefer top, but switch to bottom if
    " cursor is too high. abort if popup doesn't have to move and no a:force
    " is given
    if !a:force && c.popup_offset == 0
        call context#util#echof('  > context#popup#redraw no force skip top')
        return
    endif

    let lines = c.lines
    if g:context.show_border && len(lines) > 0
        let lines[-1] = s:get_border_line(a:winid, 1)
        let c.lines = lines
    endif

    let c.popup_offset = 0

    call context#util#echof('  > context#popup#redraw', len(lines))
    if g:context.presenter == 'nvim-float'
        call context#popup#nvim#redraw(a:winid, popup, lines)
    elseif g:context.presenter == 'vim-popup'
        call context#popup#vim#redraw(a:winid, popup, lines)
    endif
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

        " if there are no lines, we reset popup_offset here so we'll try to
        " show the next non empty context at the top again
        let w:context.popup_offset = 0

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

    " NOTE: we use a non breaking space here again before the buffer name
    let border = ' *' .g:context.char_border . '* '
    let tag = s:context_buffer_name
    call matchadd(g:context.highlight_border, border, 10, -1, {'window': popup})
    call matchadd(g:context.highlight_tag,    tag,    10, -1, {'window': popup})

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
    let indent = a:indent ? c.indent : 0
    " let indent = 0

    let line_len = c.size_w - c.padding - indent - 1
    if g:context.show_tag
        let line_len -= len(s:context_buffer_name) + 1
    endif

    " NOTE: we use a non breaking space before the buffer name because there
    " can be some display issues in the Kitty terminal with a normal space
    let border_line = ''
                \ . repeat(' ', indent)
                \ . repeat(g:context.char_border, line_len)
                \ . ' '
    if g:context.show_tag
        let border_line .= ''
                    \ . s:context_buffer_name
                    \ . ' '
    endif
    return border_line
endfunction
