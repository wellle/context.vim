function! context#popup#nvim#open() abort
    call context#util#echof('    > context#popup#nvim#open')

    let buf = nvim_create_buf(v:false, v:true)
    let popup = nvim_open_win(buf, 0, {
                \ 'relative':  'editor',
                \ 'row':       0,
                \ 'col':       0,
                \ 'width':     1,
                \ 'height':    1,
                \ 'focusable': v:false,
                \ 'style':     'minimal',
                \ })

    call setwinvar(popup, '&wrap', 0)
    call setwinvar(popup, '&foldenable', 0)
    call setwinvar(popup, '&tabstop', &tabstop)
    call setwinvar(popup, '&winhighlight',
                \ 'FoldColumn:Normal,Normal:' . g:context.highlight_normal)

    return popup
endfunction

function! context#popup#nvim#redraw(winid, popup, lines) abort
    call context#util#echof('    > context#popup#nvim#redraw', len(a:lines))

    let buf = winbufnr(a:popup)
    call nvim_buf_set_lines(buf, 0, -1, v:true, a:lines)

    let c = getwinvar(a:winid, 'context')
    call nvim_win_set_config(a:popup, {
                \ 'relative': 'editor',
                \ 'row':      c.pos_y - 1,
                \ 'col':      c.pos_x - 1,
                \ 'height':   len(a:lines),
                \ 'width':    c.size_w,
                \ })

    call setwinvar(a:popup, '&list', &list)

    " NOTE: because of some neovim limitation we have to temporarily switch to
    " the popup window so we can clear the highlighting
    " https://github.com/neovim/neovim/issues/10822
    " TODO: seems like this still triggers a BufEnter autocmd which triggers a
    " context, stop that from happening
    execute 'noautocmd' bufwinnr(buf) . 'wincmd w'
    call clearmatches()
    wincmd p
endfunction

function! context#popup#nvim#close(popup) abort
    call nvim_win_close(a:popup, v:true)
endfunction

function! context#popup#nvim#redraw_screen() abort
    if g:context.nvim_no_redraw
        return
    endif

    " NOTE: this redraws the screen. this is needed because there's
    " a redraw issue: https://github.com/neovim/neovim/issues/11597
    " TODO: remove this once that issue has been resolved
    " sometimes it's not enough to :mode without :redraw we do it here because
    " it's not needed for when we call update from layout
    redraw
    mode
endfunction
