" TODO: don't hide cursor, hide (partially) context instead, hint that it's
" partial?
" TODO: multiple tabs don't work, look into that

" TODO: these used to be s:, are now g:, need update/move?
" consts
let g:context_buffer_name = '<context.vim>'

" cached
let g:context_ellipsis  = repeat(g:context_ellipsis_char, 3)
let g:context_ellipsis5 = repeat(g:context_ellipsis_char, 5)
" TODO: use make_line later?
let g:context_nil_line = context#line#make(0, 0, '')

" state
" NOTE: there's more state in window local w: variables
let s:activated     = 0
let s:ignore_update = 0


" call this on VimEnter to activate the plugin
function! context#activate() abort
    " for some reason there seems to be a race when we try to show context of
    " one buffer before another one gets opened in startup
    " to avoid that we wait for startup to be finished
    let s:activated = 1
    call context#update(0, 'activate')
endfunction

function! context#enable() abort
    let g:context_enabled = 1
    call context#update(1, 'enable')
endfunction

function! context#disable() abort
    let g:context_enabled = 0

    " TODO: extract one general function, similar in other places
    " TODO: also how can we avoid the explicit presenter checks?
    call context#popup#clear()
    if g:context_presenter == 'preview'
        call context#preview#close()
    endif
endfunction

function! context#toggle() abort
    if g:context_enabled
        call context#disable()
    else
        call context#enable()
    endif
endfunction

function! context#update(force_resize, source) abort
    if 0
                \ || !g:context_enabled
                \ || !s:activated
                \ || s:ignore_update
                \ || &previewwindow
                \ || mode() != 'n'
        return
    endif

    let s:ignore_update = 1

    let winid = win_getid()

    let w:context_needs_update = a:force_resize
    let w:context_needs_layout = a:force_resize
    let w:context_needs_move   = a:force_resize
    call context#util#update_state()
    call context#util#update_window_state(winid)

    if w:context_needs_update || w:context_needs_layout || w:context_needs_move
        call context#util#echof()
    endif

    if w:context_needs_update
        call context#context#update(winid, 1, a:force_resize, a:source)
    endif

    if g:context_presenter != 'preview'
        if w:context_needs_layout
            call context#popup#update_layout()
        endif

        " TODO: only if we didn't above? currently we do it on every cursor
        " line move...
        if w:context_needs_move
            call context#popup#move(winid)
        endif
    endif

    let w:context_needs_update = 0
    let w:context_needs_layout = 0
    let w:context_needs_move   = 0

    let s:ignore_update = 0
endfunction
