let s:activated     = 0
let s:ignore_update = 0
let s:peek          = 0

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
    unlet! w:context " clear stale cache
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
        echom 'context.vim: disabled'
    else
        call context#enable()
        echom 'context.vim: enabled'
    endif
endfunction

function! context#peek() abort
    " enable and set the peek flag (to disable on next update)
    call context#enable()
    let s:peek = 1
endfunction

function! context#update(...) abort
    " NOTE: this function used to have two arguments, but now it's only one
    " for compatibility reasons we still allow multiple arguments
    let source = a:000[-1]

    if s:peek && source != 'CursorHold'
        " if peek was used disable on next update (but ignore CursorHold)
        let s:peek = 0
        call context#disable()
        return
    endif

    if 0
                \ || !s:activated
                \ || s:ignore_update
                \ || &previewwindow
                \ || mode() != 'n'
                \ || !context#util#active()
        return
    endif

    let winid = win_getid()

    if !exists('w:context')
        let w:context = {
                    \ 'lines_top':     [],
                    \ 'lines_bottom':  [],
                    \ 'pos_y':         0,
                    \ 'pos_x':         0,
                    \ 'size_h':        0,
                    \ 'size_w':        0,
                    \ 'base_line':     0,
                    \ 'needs_layout':  0,
                    \ 'needs_move':    0,
                    \ 'needs_update':  0,
                    \ 'padding':       0,
                    \ 'top_line':      0,
                    \ 'cursor_line':   0,
                    \ }
    endif

    call context#util#update_state()
    call context#util#update_window_state(winid)

    if w:context.needs_update || w:context.needs_layout || w:context.needs_move
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
    endif
endfunction
