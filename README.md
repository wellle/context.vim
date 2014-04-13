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
together with other plugins presented in the same talk.


Authors
-------

* Gioele Barabucci (made the plugin Linux-compatible, maintainer)
* Damian Conway (original author)


License
-------

The original file states "This file is placed in the public domain."
