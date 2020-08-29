# context.vim

A Vim plugin that shows the context of the currently visible buffer contents. It's supposed to work on a wide range of file types, but is probably most useful when looking at source code files. In most programming languages this context will show you which function you're looking at, and within that function which loops or conditions are surrounding the visible code.

Here's an animation which shows it in action. See below for an explanation.

![][scroll.gif]

[scroll.gif]: https://raw.githubusercontent.com/wellle/images/master/context-scroll.gif


## Motivation

Do you ever find yourself looking at code with long functions or deeply nested loops and conditions? Do you ever lose your place and start scrolling in your buffer to see where you are? This plugin aims to always show you that context for your currently active buffer so you always know your place.


## Example

Here's an screenshot showing parts of `eval.c` in the Vim source code:

![][example.png]

[example.png]: https://raw.githubusercontent.com/wellle/images/master/context-example.png

At the bottom you see the actual buffer. At the top you see a popup window used by **context.vim** to show the context of that code. So here we are looking at some code within the `echo_string` function. And within that function we are currently handling the case where `tv->v_type` is `VAR_LIST` and so on.

In the animation above you can see how the context changes as we scroll through this function.


## How it works

This plugin should work out of the box for most file types. It's based on indentation and some regular expressions.

Below is an illustration of how it works: Start at the grey box in the bottom left corner. It shows the original visible buffer content as you would see it without this plugin. Above the box we can see what's usually hidden, the file contents above the visible area. You'd need to scroll up to see it.

This plugin scans upwards through these hidden lines to collect the context. Every time it hits a line with a lower indentation than the last one it will add it to the context. There is also some logic to add lines with same indentation to the context in some cases. For example it adds the `else` line which belongs to the first `{` and also the `else if` and `if` lines. So you know exactly what this `else` case is about. All lines which are part of the context in this example are displayed with color while the remaining lines are greyed out.

In the top right corner we see again all these lines which make up the context. Below is a condensed version where some lines were joined. We show ellipsis (`···`) between the joined parts if there was text between them in the original buffer. So this tells you that there was code within the `else if` block, but not between the `else if` condition and the `{` line below it.

In the bottom right corner we see the final result: The context is displayed in a preview window above the original buffer.

![][how.png]

[how.png]: https://raw.githubusercontent.com/wellle/images/master/context-how.png


## Installation

| Plugin Manager         | Command                               |
|------------------------|---------------------------------------|
| [Vim-plug][vim-plug]   | `Plug 'wellle/context.vim'`           |
| [Vundle][vundle]       | `Bundle 'wellle/context.vim'`         |
| [NeoBundle][neobundle] | `NeoBundle 'wellle/context.vim'`      |
| [Dein][dein]           | `call dein#add('wellle/context.vim')` |


[vim-plug]:  https://github.com/junegunn/vim-plug
[vundle]:    https://github.com/gmarik/vundle
[neobundle]: https://github.com/Shougo/neobundle.vim
[dein]:      https://github.com/Shougo/dein.vim


## Settings

This plugin is supposed to work out of the box. But there are some variables which can be set to different values to tweak the behavior. Below we show each of those together with their default value for reference. Copy/paste these lines to your vimrc and change the values to your liking.

If you feel like one of these default settings are bad in some way or could be improved to create more useful contexts in some file types, please open an issue and let me know. Also if you feel like any of these settings would need to be settable on a per buffer/per file type basis.

```vim
let g:context_enabled = 1
```
This plugin is enabled by default. Set this variable to `0` to disable it. You can then use `:ContextEnable` or `:ContextToggle` to enable it on demand.

```vim
let g:context_filetype_blacklist = []
```
By default, no filetypes will be ignored for the context buffer to appear. If you wish to blacklist a specific filetype, add the name of the filetype to this list.

```vim
let g:context_add_mappings = 1
```
By default we create some mappings to update the context on all Vim commands which scroll the buffer. Set this variable to `0` to disable that. See below on how to customize these mappings if needed.

Note: Ideally there would be an auto command event for when the buffer had scrolled, but unfortunately that doesn't exist. [vim#776]

```vim
let g:context_add_autocmds = 1
```
By default we set up some auto commands to update the context every time the buffer might have scrolled. Most notably on `CursorMoved`. Set this variable to `0` to disable that. See below on how to customize these auto commands if needed.

```vim
let g:context_presenter = <depends>
```

This variable can be used to control how the context is presented. The default logic works like this: If you're running a Neovim version which supports floating windows, use them (`'nvim-float'`). If you're running a Vim version which supports popup windows, use them (`'vim-popup'`). Otherwise use a preview window (`'preview'`). So for example you could force the usage of preview windows by setting `g:context_presenter` to `'preview'`. It is recommended to stick to the default though (by not setting this variable) as floating/popup windows should lead to the best experience.

```vim
let g:context_max_height = 21
```
If the context gets bigger than 21 lines, it will only show the first ten, then one line with ellipsis (`···`) and then the last ten context lines.

```vim
let g:context_max_per_indent = 5
```
If we extend the context on some indent and collect more than five lines, it will only show the first two, ellipsis (`···`) and then the last two.

Note: This is likely to happen if you have many `else if` conditions or many `case` statements within a `switch`.

```vim
let g:context_max_join_parts = 5
```
If we extend the context on some indent we try to join them. By default we join a context line into the previous line of same indent if the former has no word characters. For example in C-style indentation we would join the `{` line to the `if (condition)` line. So in the context it would show up as `if (condition) {`.

In complex cases there can be a big number of such context lines which we will join together. By default we only show up to 5 such parts.

Note: This can happen if you have long lists of struct literals, so in the context it would look like `{ ··· }, { ··· }, { ··· }`. Set `g:context_max_join_parts` to 2 or 1 to shorten this to `{ ···` or just `{` respectively.

```vim
let g:context_ellipsis_char = '·'
```
By default we use this character (digraph `.M`) in our ellipsis (`···`). Change this variable if this character doesn't work for you or if you don't like it.

```vim
g:context_border_char = '━'
```

If your Vim/Neovim version supports popup/floating windows we draw a line to separate the context from your buffer context. This character is used to do that.

```vim
let g:context_highlight_normal = 'Normal'
let g:context_highlight_border = 'Comment'
let g:context_highlight_tag    = 'Special'
```

If your Vim/Neovim version supports popup/floating windows we use these highlight groups for the popup window (`normal`), the border line (`border`) and the "tag" (`<context.vim>` at the end of the border line) (`tag`). By default the popup window uses the same background color as your buffer. For example you could change that to make it more visually distinct by setting `g:context_highlight_normal` to `'PMenu'`.

If you use Vim you can define your own highlight group like `highlight MyColor ctermbg=lightblue` and set `g:context_highlight_normal` to `'MyColor'`. In Neovim this is currently not supported (see `:h 'winhl'`).

Note: These highlight settings can also be used to hide the tag (`let g:context_highlight_tag = '<hide>'`) or the full border line (`let g:context_highlight_border = '<hide>'`).

```vim
let g:context_skip_regex = '^\s*\($\|#\|//\|/\*\|\*\($\|/s\|\/\)\)'
```
If a buffer line matches this regular expression then it will be fully ignored for context building. By default we skip empty lines, comments and C preprocessor statements.

```vim
let g:context_extend_regex = '^\s*\([]{})]\|end\|else\|case\>\|default\>\)'
```
If a buffer line matches this regular expression, **context.vim** will extend the context on the current indentation level. So instead of searching upwards for the first line of smaller indent, it will also look for lines with the same indent. For example if we find an `else` or `else if` line, we will look upwards for other `else if` or the initial `if` line. That way all these conditions will be part of the context so it's more clear of what the current case actually is about. Also by default we extend if the current line starts with any square bracket or curly brace. So for example in a C-style `if` condition we would extend the `{` line to include the `if` line.

```vim
let g:context_join_regex = '^\W*$'
```
If we extended the context on some indent, we will join a line of this indent into the one above if the lower one matches this regular expression. So back in the C-style case where our context contains an `if (condition)` line and a `{` line below, they will be merged to `if (condition) {`. And that is because the `{` line matched this regular expression. By default we join everything which has no word characters.

TODO: update docs
```vim
let g:Context_indent = { line -> [indent(line), indent(line)] }
```
By default we create the context based on the indentation of the context lines. As we scan through the buffer lines we add lines to the context if they have less indent than the last context line. To get the indentation of a given buffer line we use the `indent()` function. You can use this setting to use your own function instead. That way you can customize what goes into your context.

The function takes a line number and is supposed to return two numbers. The first one is the level. Smaller level means bigger scope, just like indentation. Make sure to return -1 if an invalid line number gets passed in, like `indent()` does. The second return value is the indentation used for display. You probably want to keep using `indent()` for this one. 

Here's an example that considers Markdown headers for the context: [#45][indent-example] (Note that you need to change `g:context_skip_regex` too to make this work)

```vim
let g:Context_border_indent = function('indent')
```
When using popup windows we indent the border line to be aligned with the context base line. You can use this setting to use a different function to control that indent. Similar to `g:Context_indent` this function also takes a line number and returns an indentation number. For example you can disable that indentation at all to always show a full width border line like this: `let g:Context_border_indent = { -> 0 }`

```vim
let g:context_nvim_no_redraw = 0
```
There's an issue in Neovim which leads to some artefacts. To avoid those we manually refresh the screen after every context update. This can lead to screen flickering, see [#23][#23]. You disable those redraws (at the cost of visual artefacts) like this: `let g:context_nvim_no_redraw = 1`


[indent-example]: https://github.com/wellle/context.vim/pull/45#issuecomment-582654810
[#23]: https://github.com/wellle/context.vim/pull/23


## Commands

By default they shouldn't be needed, but some command are made available for your customization needs:

```vim
:ContextActivate
```
If you disabled auto commands (see below) you need to activate this plugin by executing this command. By default it's called on the `VimEnter` auto command.

```vim
:ContextEnable
```
If you `let g:context_enabled = 0` to disable it by default or have disabled it with one of the commands below you can use this command to enable it.

```vim
:ContextDisable
```
Use this command to disable the plugin. This also hides the context window. Use `:ContextEnable` to enable it again later.

```vim
:ContextToggle
```
Use this command to toggle between enabling and disabling this plugin. This is useful in mappings.

```vim
:ContextEnableWindow
```
Similar to `:ContextEnable`, but only affects the current window.

```vim
:ContextDisableWindow
```
Similar to `:ContextDisable`, but only affects the current window.

```vim
:ContextToggleWindow
```
Similar to `:ContextToggle`, but only affects the current window.

```vim
:ContextPeek
```
Use this command to temporarily show the current context, but hide it again on the next cursor movement.

```vim
:ContextUpdate
```
If you disabled auto commands (see below) the context won't be updated automatically. Use this command to update it manually.


## Auto commands

This plugin uses auto command to update the context automatically. You can disable that by setting `g:context_add_autocmds` to `0`.

If you want to set up your own auto commands, here are the default ones for reference:

```vim
autocmd VimEnter     * ContextActivate
autocmd BufAdd       * call context#update('BufAdd')
autocmd BufEnter     * call context#update('BufEnter')
autocmd CursorMoved  * call context#update('CursorMoved')
autocmd VimResized   * call context#update('VimResized')
autocmd CursorHold   * call context#update('CursorHold')
autocmd User GitGutter call context#update('GitGutter')
autocmd OptionSet number,relativenumber,numberwidth,signcolumn,tabstop,list
            \          call context#update('OptionSet')
```

Note the `VimEnter` one. When Vim starts this plugin isn't active yet, even if enabled. That is because there are some issues with trying to open a preview window before Vim finished opening all windows for the provided file arguments. So if you disable auto commands you will need to call `:ContextActivate` in some way to activate this plugin.


## Mappings

Unfortunately there's no auto command for when the buffer has scrolled [vim#776]. As the next best thing we add a few mappings for commands which scroll the buffer. So whenever one of these commands get used, we call a function to update the context. You can disable that by setting `g:context_add_mappings` to `0`.

If you want to create your own mappings, here are the default ones for reference:

```vim
nnoremap <silent> <expr> <C-Y> context#util#map('<C-Y>')
nnoremap <silent> <expr> <C-E> context#util#map('<C-E>')
nnoremap <silent> <expr> zz    context#util#map('zz')
nnoremap <silent> <expr> zb    context#util#map('zb')
nnoremap <silent> <expr> zt    context#util#map_zt()
nnoremap <silent> <expr> H     context#util#map_H()
```

Note how `zz`, `zt`, and `zb` get called twice in the mapping before updating the context. This is because otherwise there are some cases where they don't work as expected.


## Contribute

Please feel free to open an issue or pull request if there's anything which you'd like to see improved or added to this plugin.

If you made a change to the regex settings and feel like it might be generally useful, please let me know so I can consider updating the defaults.

Thank you! :kissing_heart:


[vim#776]: https://github.com/vim/vim/issues/776

