let s:activated     = 0
let s:ignore_update = 0

" call this on VimEnter to activate the plugin
function! context#activate() abort
    " for some reason there seems to be a race when we try to show context of
    " one buffer before another one gets opened in startup
    " to avoid that we wait for startup to be finished
    let s:activated = 1
    call context#update('activate')
endfunction

function! context#enable() abort
    let g:context.enabled = 1
    call context#update('enable')
endfunction

function! context#disable() abort
    let g:context.enabled = 0

    if g:context.presenter == 'preview'
        call context#preview#close()
    else
        call context#popup#clear()
    endif
endfunction

function! context#toggle() abort
    if g:context.enabled
        call context#disable()
    else
        call context#enable()
    endif
endfunction

function! context#update(source) abort
    if 0
                \ || !g:context.enabled
                \ || !s:activated
                \ || s:ignore_update
                \ || &previewwindow
                \ || mode() != 'n'
        return
    endif

    let winid = win_getid()

    if !exists('w:context')
        let w:context = {
                    \ 'top_lines':     [],
                    \ 'bottom_lines':  [],
                    \ 'line':          0,
                    \ 'col':           0,
                    \ 'width':         0,
                    \ 'height':        0,
                    \ 'cursor_offset': 0,
                    \ 'indent':        0,
                    \ 'needs_layout':  0,
                    \ 'needs_move':    0,
                    \ 'needs_update':  0,
                    \ 'padding':       0,
                    \ 'resize_level':  0,
                    \ 'scroll_offset': 0,
                    \ 'top_line':      0,
                    \ }
    endif

    call context#util#update_state()
    call context#util#update_window_state(winid)

    if w:context.needs_update || w:context.needs_layout || w:context.needs_move
        call context#util#echof()
        call context#util#echof('> context#update', a:source)
        call context#util#log_indent(2)

        if g:context.presenter == 'preview'
            let s:ignore_update = 1

            if w:context.needs_update
                let w:context.needs_update = 0
                call context#preview#update_context()
            endif

            let s:ignore_update = 0

        else " popup
            if w:context.needs_update
                let w:context.needs_update = 0
                call context#popup#update_context()
            endif

            if w:context.needs_layout
                let w:context.needs_layout = 0
                call context#popup#layout()
            endif

            if w:context.needs_move
                let w:context.needs_move = 0
                call context#popup#redraw(winid, 0)
            endif
        endif

        call context#util#log_indent(-2)
    endif
endfunction

function! context#zt() abort
    if !g:context.enabled
        return 'zt'
    endif

    let suffix = ":call context#update('zt')\<CR>"
    if g:context.presenter == 'preview' || v:count != 0
        " NOTE: see plugin/context.vim for why we use double zt here
        return 'ztzt' . suffix
    endif

    let cursor_line = line('.')
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

function! context#h() abort
    if !g:context.enabled
        return 'H'
    endif

    if g:context.presenter == 'preview'
        return 'H'
    endif

    if get(w:context, 'popup_offset') > 0
        return 'H'
    endif

    let lines = w:context.top_lines
    if len(lines) == 0
        return 'H'
    endif

    let n = len(lines) + v:count1
    return "\<ESC>" . n . 'H'
endfunction

function! context#ce() abort
    let suffix = "\<C-E>:call context#update('C-E')\<CR>"
    if g:context.presenter == 'preview' || get(w:context, 'popup_offset') > 0
        return suffix
    endif

    let next_top_line = line('w0') + v:count1
    let [lines, _, _] = context#popup#get_context(next_top_line)
    if len(lines) == 0
        return suffix
    endif

    let cursor_line = line('.')
    " how much do we need to go down to have enough lines above the cursor to
    " fit the context above?
    let n = len(lines) - (cursor_line - next_top_line)
    if n <= 0
        return suffix
    endif

    " move down n lines before scrolling
    return "\<Esc>" . n . 'j' . v:count1 . suffix
endfunction

function! context#k() abort
    if g:context.presenter == 'preview' || get(w:context, 'popup_offset') > 0
        return 'k'
    endif

    let top_line = line('w0')
    let next_cursor_line = line('.') - v:count1
    let n = len(w:context.top_lines) - (next_cursor_line - top_line)
    " call context#util#echof('k', len(w:context.top_lines), next_cursor_line, top_line, n)
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
