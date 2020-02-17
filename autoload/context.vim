let s:activated     = 0
let s:ignore_update = 0

" call this on VimEnter to activate the plugin
function! context#activate() abort
    " for some reason there seems to be a race when we try to show context of
    " one buffer before another one gets opened in startup
    " to avoid that we wait for startup to be finished
    let s:activated = 1
    unlet! w:context " clear stale cache (from BufEnter)
    call context#update('activate')
endfunction

function! context#enable(arg) abort
    call s:set_enabled(a:arg, 1)
    call context#update('enable')
endfunction

function! context#disable(arg) abort
    call s:set_enabled(a:arg, 0)

    if g:context.presenter == 'preview'
        call context#preview#close()
    else
        if a:arg == 'window'
            call context#popup#close()
        else
            call context#popup#clear()
        endif
    endif
endfunction

function! context#toggle(arg) abort
    if a:arg == 'window'
        let arg = 'window'
        let enabled = w:context.enabled
    else
        let arg = 'all'
        let enabled = g:context.enabled
    endif

    if enabled
        call context#disable(arg)
        echom 'context.vim: disabled' arg
    else
        call context#enable(arg)
        echom 'context.vim: enabled' arg
    endif
endfunction

function! context#peek() abort
    " enable and set the peek flag (to disable on next update)
    call context#enable('window')
    let w:context.peek = 1
endfunction

function! context#update(...) abort
    " NOTE: this function used to have two arguments, but now it's only one
    " for compatibility reasons we still allow multiple arguments
    let source = a:000[-1]

    if !exists('w:context')
        let w:context = {
                    \ 'enabled':       g:context.enabled,
                    \ 'lines_top':     [],
                    \ 'lines_bottom':  [],
                    \ 'pos_y':         0,
                    \ 'pos_x':         0,
                    \ 'size_h':        0,
                    \ 'size_w':        0,
                    \ 'indent':        0,
                    \ 'needs_layout':  0,
                    \ 'needs_move':    0,
                    \ 'needs_update':  0,
                    \ 'padding':       0,
                    \ 'top_line':      0,
                    \ 'cursor_line':   0,
                    \ 'peek':          0,
                    \ }
    endif

    if 1
                \ && w:context.peek
                \ && source != 'CursorHold'
                \ && source != 'GitGutter'
        " if peek was used disable on next update
        " (but ignore CursorHold and GitGutter)
        let w:context.peek = 0
        call context#util#echof('> context#update unpeek', source)
        call context#disable('window')
        return
    endif

    let winid = win_getid()
    call context#util#update_state()
    call context#util#update_window_state(winid)

    if 0
                \ || !s:activated
                \ || s:ignore_update
                \ || &previewwindow
                \ || mode() != 'n'
                \ || !context#util#active()
        let w:context.needs_update = 0
        let w:context.needs_move   = 0
        " NOTE: we still consider needs_layout even if this buffer is disabled
    endif

    if g:context.presenter == 'preview'
        let w:context.needs_layout = 0
    endif

    if !w:context.needs_update && !w:context.needs_layout && !w:context.needs_move
        return
    endif

    call context#util#echof()
    call context#util#echof('> context#update', source)
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
endfunction

function! s:set_enabled(arg, enabled) abort
    if a:arg == 'window'
        let winids = [winnr()] " only current window
    else
        let winids = range(1, winnr('$')) " all windows
        let g:context.enabled = a:enabled
    endif

    for winid in winids
        let c = getwinvar(win_getid(winid), 'context', {})
        let c.enabled = a:enabled
        let c.top_line = 0 " don't rely on old cache
    endfor
endfunction
