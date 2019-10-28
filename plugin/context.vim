" TODO: make this not show up in command line
map \x :call Context()<CR>

" TODO: don't use uppercase functions?
function! Context()
    let view = winsaveview()
    normal! H
    let lines = []
    let oldpos = getpos('.')
    while 1
        normal [-
        let newpos = getpos('.')
        if newpos == oldpos
            break
        endif
        call insert(lines, getline('.'), 0)
        let oldpos = newpos
    endwhile
    echo join(lines, "\n")
    call winrestview(view)
endfunction
