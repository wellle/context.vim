function! context#mapping#ce() abort
    if !g:context.enabled
        return "\<C-E>"
    endif

    let suffix = "\<C-E>:call context#update('C-E')\<CR>"
    if g:context.presenter == 'preview' || get(w:context, 'popup_offset') > 0
        return suffix
    endif

    let next_top_line = w:context.top_line + v:count1
    let [lines, _, _] = context#popup#get_context(next_top_line)
    if len(lines) == 0
        return suffix
    endif

    let cursor_line = w:context.cursor_line
    " how much do we need to go down to have enough lines above the cursor to
    " fit the context above?
    let n = len(lines) - (cursor_line - next_top_line)
    if n <= 0
        return suffix
    endif

    " move down n lines before scrolling
    return "\<Esc>" . n . 'j' . v:count1 . suffix
endfunction

function! context#mapping#zt() abort
    if !g:context.enabled
        return 'zt'
    endif

    let suffix = ":call context#update('zt')\<CR>"
    if g:context.presenter == 'preview' || v:count != 0
        " NOTE: see plugin/context.vim for why we use double zt here
        return 'ztzt' . suffix
    endif

    let cursor_line = w:context.cursor_line
    let base_line = context#line#get_base_line(cursor_line)
    let lines = context#context#get(base_line)
    if len(lines) == 0
        return 'zt' . suffix
    endif

    let n = cursor_line - w:context.top_line - len(lines) - 1
    " call context#util#echof('zt', w:context.top_line, cursor_line, len(lines), n)

    if n == 0
        return "\<Esc>"
    elseif n < 0
        return 'zt' . suffix
    endif

    return "\<ESC>" . n . "\<C-E>" . suffix
endfunction

function! context#mapping#k() abort
    if !g:context.enabled
        return 'k'
    endif

    if g:context.presenter == 'preview' || get(w:context, 'popup_offset') > 0
        return 'k'
    endif

    let top_line = w:context.top_line
    let next_cursor_line = w:context.cursor_line - v:count1
    let n = len(w:context.lines_top) - (next_cursor_line - top_line)
    " call context#util#echof('k', len(w:context.lines_top), next_cursor_line, top_line, n)
    if n <= 0
        " current context still fits
        return 'k'
    endif

    let base_line = context#line#get_base_line(next_cursor_line)
    let lines = context#context#get(base_line)
    if len(lines) == 0
        return 'k'
    endif

    let n = len(lines) + 1 - (next_cursor_line - top_line)
    " call context#util#echof('k', len(lines), next_cursor_line, top_line, n)
    if n <= 0
        " new context will fit
        return 'k'
    endif

    " scroll so that the new context will fit
    return "\<Esc>" . n . "\<C-Y>" . v:count1. 'k'
endfunction

function! context#mapping#h() abort
    if !g:context.enabled
        return 'H'
    endif

    if g:context.presenter == 'preview'
        return 'H'
    endif

    if get(w:context, 'popup_offset') > 0
        return 'H'
    endif

    let lines = w:context.lines_top
    if len(lines) == 0
        return 'H'
    endif

    let n = len(lines) + v:count1
    return "\<ESC>" . n . 'H'
endfunction
