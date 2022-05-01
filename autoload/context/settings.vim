function! context#settings#parse() abort
    if exists('g:context')
    endif

    if exists('g:context_presenter')
        let presenter = g:context_presenter
    elseif has('nvim-0.4.0')
        let presenter = 'nvim-float'
    elseif has('patch-8.1.1364')
        let presenter = 'vim-popup'
    else
        let presenter = 'preview'
    endif

    " set this to 0 to disable this plugin on launch
    " (use :ContextEnable to enable it later)
    let enabled = get(g:, 'context_enabled', 1)

    " if you wish to blacklist a specific filetype, add the name of the
    " filetype to this list.
    let filetype_blacklist = get(g:, 'context_filetype_blacklist', [])

    " set to 0 to disable default mappings and/or auto commands
    let add_mappings = get(g:, 'context_add_mappings', 1)
    let add_autocmds = get(g:, 'context_add_autocmds', 1)

    " how many lines to use at most for the context
    let max_height = get(g:, 'context_max_height', 21)

    " how many lines are allowed per level
    " NOTE: the setting is called per_indent for legacy reasons
    " TODO: might want to rename the setting and keep the legacy fallback
    let max_per_level = get(g:, 'context_max_per_indent', 5)

    " how many lines can be joined in one line (if they match
    " regex_join) before the ones in the middle get hidden
    let max_join_parts = get(g:, 'context_max_join_parts', 4)

    " which character to use for the ellipsis "..."
    let char_ellipsis = get(g:, 'context_ellipsis_char', '·')

    " NOTE: we switched away from the earlier default value '▬' because there
    " still is a display issue in the Kitty terminal:
    " ▬▬▬▬ <context.vim>
    " if you look at that line in terminal you will notice that the last
    " instance of the character is displayed differently than the others.
    " we used to work around this by using a non breaking space after the last
    " character:
    " ▬▬▬▬ <context.vim>
    " but this led to other issues later on (see #81) so we switched to this
    " new default border char which doesn't have such issues
    let char_border = get(g:, 'context_border_char', '━')

    " indent function used to create the context
    let Default_indent = function('s:indent')
    let Indent         = get(g:, 'Context_indent',        Default_indent)
    let Border_indent  = get(g:, 'Context_border_indent', Default_indent)

    if type(Indent(0)) == type(0)
        echom 'context.vim warning:'
        echom '  The interfaces of custom indent functions have changed. They expect two'
        echom '  return values now. Your implementation is ignored until you update it'
        echom '  accordingly. Sorry for the inconvenience!'
        echom '  See https://github.com/wellle/context.vim/pull/85'
        let Indent        = Default_indent
        let Border_indent = Default_indent
    endif

    " TODO: skip label lines

    " lines matching this regex will be ignored for the context
    " match whitespace only lines to show the full context
    " also by default excludes comment lines etc.
    let regex_skip = get(g:, 'context_skip_regex',
                \ '^\([<=>]\{7\}\|\s*\($\|#\|//\|/\*\|\*\($\|\s\|/\)\)\)')

    " if a line matches this regex we will extend the context by looking upwards
    " for another line with the same indent
    " (to show the if which belongs to an else etc.)
    let regex_extend = get(g:, 'context_extend_regex',
                \ '^\s*\([]{})]\|end\|else\|\(case\|default\|done\|elif\|fi\)\>\)')

    " if a line matches this regex we consider joining it into the one above
    " for example a `{` might be lifted to the preceeding `if` line
    let regex_join = get(g:, 'context_join_regex', '^\W*$')

    let default_highlight_border = 'Comment'
    let default_highlight_tag    = 'Special'

    let highlight_normal = get(g:, 'context_highlight_normal', 'Normal')
    let highlight_border = get(g:, 'context_highlight_border', default_highlight_border)
    let highlight_tag    = get(g:, 'context_highlight_tag',    default_highlight_tag)
    let show_border = 1
    let show_tag    = 1

    if highlight_border == '<hide>'
        let highlight_border = default_highlight_border
        let show_border = 0
    endif
    if highlight_tag == '<hide>'
        let highlight_tag = default_highlight_tag
        let show_tag = 0
    endif

    " Deprecated: Disable redraw to avoid flicker in older Neovim versions,
    " see popup/nvim.vim
    let nvim_no_redraw = get(g:, 'context_nvim_no_redraw', 0)

    let logfile = get(g:, 'context_logfile', '')

    " transform list to lookup dictionary
    let blacklist = {}
    for filetype in filetype_blacklist
        let blacklist[filetype] = 1
    endfor

    let g:context = {
                \ 'presenter':           presenter,
                \ 'enabled':             enabled,
                \ 'filetype_blacklist':  blacklist,
                \ 'add_mappings':        add_mappings,
                \ 'add_autocmds':        add_autocmds,
                \ 'max_height':          max_height,
                \ 'max_per_level':       max_per_level,
                \ 'max_join_parts':      max_join_parts,
                \ 'char_ellipsis':       char_ellipsis,
                \ 'char_border':         char_border,
                \ 'regex_skip':          regex_skip,
                \ 'regex_extend':        regex_extend,
                \ 'regex_join':          regex_join,
                \ 'highlight_normal':    highlight_normal,
                \ 'highlight_border':    highlight_border,
                \ 'highlight_tag':       highlight_tag,
                \ 'show_border':         show_border,
                \ 'show_tag':            show_tag,
                \ 'nvim_no_redraw':      nvim_no_redraw,
                \ 'logfile':             logfile,
                \ 'ellipsis':            repeat(char_ellipsis, 3),
                \ 'ellipsis5':           repeat(char_ellipsis, 5),
                \ 'Indent':              Indent,
                \ 'Border_indent':       Border_indent,
                \ 'popups':              {},
                \ 'windows':             {},
                \ }
endfunction

function! s:indent(line) abort
    let indent = indent(a:line)
    return [indent, indent]
endfunction
