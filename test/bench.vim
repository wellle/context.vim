GitGutterDisable
set nolazyredraw

edit bench.c

let g:context.bench_limit = 200

execute 'profile start log/' . strftime('%Y-%m-%d_%H-%M-%S') . '.log'
profile file *
profile func *

for i in range(1, g:context.bench_limit)
    call feedkeys("\<C-E>")
    redraw
endfor
