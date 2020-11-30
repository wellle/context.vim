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

function! context#enable(all) abort
    call s:set_enabled(a:all, 1)
    call context#update('enable')
endfunction

function! context#disable(all) abort
    call s:set_enabled(a:all, 0)

    if g:context.presenter == 'preview'
        call context#preview#close()
    else
        if a:all
            call context#popup#clear()
        else
            call context#popup#close()
        endif
    endif
endfunction

function! context#toggle(all) abort
    if a:all
        let scope = 'all'
        let enabled = g:context.enabled
    else
        let scope = 'window'
        let enabled = w:context.enabled
    endif

    if enabled
        call context#disable(a:all)
        echom 'context.vim: disabled' scope
    else
        call context#enable(a:all)
        echom 'context.vim: enabled' scope
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
                    \ 'enabled':            g:context.enabled,
                    \ 'lines':              [],
                    \ 'pos_y':              0,
                    \ 'pos_x':              0,
                    \ 'size_h':             0,
                    \ 'size_w':             0,
                    \ 'level':              0,
                    \ 'indent':             0,
                    \ 'needs_layout':       0,
                    \ 'needs_update':       0,
                    \ 'number_width':       0,
                    \ 'sign_width':         0,
                    \ 'padding':            0,
                    \ 'top_line':           0,
                    \ 'bottom_line':        0,
                    \ 'cursor_line':        0,
                    \ 'peek':               0,
                    \ 'force_fix_strategy': '',
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

    if source == 'OptionSet'
        " some options like 'relativenumber' and 'tabstop' don't change any
        " currently tracked state. let's just always update on OptionSet.
        let w:context.needs_update = 1
    endif

    if 0
                \ || !s:activated
                \ || s:ignore_update
                \ || &previewwindow
                \ || mode() != 'n'
                \ || !context#util#active()
                \ || bufname("%") =~# '^term://'
        let w:context.needs_update = 0
        " NOTE: we still consider needs_layout even if this buffer is disabled
    endif

    if g:context.presenter == 'preview'
        let w:context.needs_layout = 0
    endif

    if !w:context.needs_update && !w:context.needs_layout
        " call context#util#echof('> context#update (nothing to do)', source)
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
    endif

    call context#util#log_indent(-2)
endfunction

function! s:set_enabled(arg, enabled) abort
    if a:arg == 'window'
        let winnrs = [winnr()] " only current window
    else
        let winnrs = range(1, winnr('$')) " all windows
        let g:context.enabled = a:enabled
    endif

    for winnr in winnrs
        let c = getwinvar(win_getid(winnr), 'context', {})
        let c.enabled = a:enabled
        let c.top_line = 0 " don't rely on old cache
    endfor
endfunction
