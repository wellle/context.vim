" cached
let g:context_ellipsis  = repeat(g:context_ellipsis_char, 3)
let g:context_ellipsis5 = repeat(g:context_ellipsis_char, 5)
let g:context_nil_line = context#line#make(0, 0, '')

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

    let winid = win_getid()

    let w:context_needs_update = a:force_resize
    let w:context_needs_layout = a:force_resize
    let w:context_needs_move   = a:force_resize
    call context#util#update_state()
    call context#util#update_window_state(winid)

    if w:context_needs_update || w:context_needs_layout || w:context_needs_move
        call context#util#echof()
        call context#util#echof('> context#update', a:source)
        call context#util#log_indent(2)

        let s:ignore_update = 1

        if w:context_needs_update
            call context#context#update(1, a:force_resize, a:source)
        endif

        if g:context_presenter != 'preview'
            if w:context_needs_layout
                call context#popup#layout()
            endif

            if w:context_needs_move
                call context#popup#move(winid)
            endif
        endif

        let s:ignore_update = 0

        call context#util#log_indent(-2)

        let w:context_needs_update = 0
        let w:context_needs_layout = 0
        let w:context_needs_move   = 0
    endif
endfunction

function! context#zt() abort
    if !g:context_enabled
        return 'zt'
    endif

    let suffix = ":call context#update(0, 'zt')\<CR>"
    if g:context_presenter == 'preview' || v:count != 0
        " TODO: mention double ztzt issue here too?
        return 'ztzt' . suffix
    endif

    let cursor_line = line('.')
    let base_line = context#line#get_base_line(cursor_line)
    let lines = context#context#get(base_line)
    if len(lines) == 0
        return 'zt' . suffix
    endif

    let n = cursor_line - w:context_top_line - len(lines) - 1
    call context#util#echof('zt', w:context_top_line, cursor_line, len(lines), n)

    if n <= 0
        return 'zt' . suffix
    endif

    return "\<ESC>" . n . "\<C-E>" . suffix
endfunction

function! context#h() abort
    if !g:context_enabled
        return 'H'
    endif

    if g:context_presenter == 'preview'
        return 'H'
    endif

    if get(w:, 'context_popup_offset') > 0
        return 'H'
    endif

    let lines = get(w:, 'context_top_lines', [])
    if len(lines) == 0
        return 'H'
    endif

    let n = len(lines) + v:count1
    return "\<ESC>" . n . 'H'
endfunction
