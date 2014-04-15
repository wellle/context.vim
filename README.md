vim-autoswap
============

Please Vim, stop with these swap file messages. Just switch to the correct window!


Why autoswap?
-------------

Dealing with swap files is annoying. Most of the time you have to deal with
a swap file because you either have the same file open in another
window or it is a swap file left there by a previous crash.

This plugin does for you what you would do in these cases:

1. Is file already open in another Vim session in some other window?
2. If so, swap to the window where we are editing that file.
3. Otherwise, if swapfile is older than file itself, just get rid of it.
4. Otherwise, open file read-only so we can have a look at it and may save it.

Damian Conway presented this plugin at OSCON 2013 in his talk
"[More instantly better Vim](http://programming.oreilly.com/2013/10/more-instantly-better-vim.html)".

The original version of this plugin (only for Mac OX) is available at <http://is.gd/IBV2013>,
together with other plugins presented in the same talk. This version has
been modified to work also on Linux systems. Both Vim and GVim are supported.


Installation
------------

Copy the `autoswap.vim` file in your `~/.vim/plugin` directory.

Or use pathogen and just clone the git repository:

    $ cd ~/.vim/bundle
    $ git clone https://github.com/gioele/vim-autoswap.git

*Linux users*: you must install `wmctrl` to be able to automatically
switch to the Vim window with the open file.
`wmctrl` is already packaged for most distributions.


Authors
-------

* Gioele Barabucci <http://svario.it/gioele> (made the plugin Linux-compatible, maintainer)
* Damian Conway <http://damian.conway.org> (original author)


Development
-----------

Code
: <http://svario.it/vim-autoswap> (redirects to GitHub)

Report issues
: <http://svario.it/vim-autoswap/issues>


License
-------

This is free software released into the public domain (CC0 license).

See the `COPYING.CC0` file or <http://creativecommons.org/publicdomain/zero/1.0/>
for more details.
