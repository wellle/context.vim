" NOTE: There are still some commands which scroll the buffer (like <C-F>) and
" others which move the cursor (like n) which we don't currently handle
" separately.
"
" If we don't handle scrolling at all the context won't update immediately
" (only on CursorHold) unless scrolling also made the cursor move.
"
" Both sorts of commands can move the cursor into the context popup window at
" the top. We move the popup to the bottom instead in those cases.
"
" Generally we'd like to avoid that case so we can keep the context visible at
" the top. The problem is that we need to handle scroll and move commands
" separately to not break expectations:
"
" To handle scroll commands we can move the cursor down (without scrolling) so
" that there's enough space at the top to show the context. We do that for
" `zt` for example.
"
" To handle move commands we can scroll the window up so that the cursor
" (together with the buffer) gets moved down.
"
" So if we'd want to never have to show the context at the bottom we would
" need to always make sure that there's enough room for the context above the
" cursor. On way to do that might be to have special mappings for all scroll
" commands (so we'd move the cursor in these cases if needed). In all other
" cases we'd assume that it was a move command and would scroll to make room.

function! context#mapping#ce() abort
    if !context#util#active()
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
    let g:context.force_temp = 'scroll'
    return 'zt'

    if !context#util#active()
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

    if &scrolloff > len(lines)
        let n = cursor_line - w:context.top_line - &scrolloff
    else
        let n = cursor_line - w:context.top_line - len(lines) - 1
    endif
    " call context#util#echof('zt', w:context.top_line, cursor_line, len(lines), n)

    if n == 0
        return "\<Esc>"
    elseif n < 0
        return 'zt' . suffix
    endif

    return "\<ESC>" . n . "\<C-E>" . suffix
endfunction

function! context#mapping#k() abort
    if !context#util#active()
        return 'k'
    endif

    if g:context.presenter == 'preview' || get(w:context, 'popup_offset') > 0
        return 'k'
    endif

    let top_line = w:context.top_line
    let next_cursor_line = w:context.cursor_line - v:count1
    let n = len(w:context.lines) - (next_cursor_line - top_line)
    " call context#util#echof('k', len(w:context.lines), next_cursor_line, top_line, n)
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

" TODO: move somewhere else if we only need this single function?
function! context#mapping#h() abort
    " TODO: handle count? (and scrolloff?)
    let g:context.force_temp = 'move'
    return 'H'

    if !context#util#active()
        return 'H'
    endif

    if g:context.presenter == 'preview'
        return 'H'
    endif

    if get(w:context, 'popup_offset') > 0
        return 'H'
    endif

    let lines = w:context.lines
    if len(lines) == 0
        return 'H'
    endif

    let n = len(lines) + v:count1
    return "\<ESC>" . n . 'H'
endfunction
