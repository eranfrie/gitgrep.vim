# gitgrep.vim

An easy way to issue a [git grep](https://git-scm.com/docs/git-grep) command across a git repository and navigate between the results.

<img src="images/sample.png" width="75%" />

## Pros

- Alternative (or addition) to *ctags* and *cscopse*.
- No need to refresh index.
- No dependencies.
- Cross language.

## Installation

- Install using your favorite package manager, e.g., [Vundle](https://github.com/VundleVim/Vundle.vim):

    1. Add the following to your .vimrc: `Plugin 'eranfrie/gitgrep.vim'`.
    2. Reload .vimrc.
    3. Run: `:PluginInstall`.

- Manual installation: copy `gitgrep.vim` to your plugin directory
    (e.g., `~/.vim/plugin/` in Unix / Mac OS X).

## Selection Menu:

- `j` / `k` / `Down` / `Up` / `PageDown` / `PageUp` to navigate the menu.
- `Enter` to select a result and jump to it.
- `Esc` / `Ctrl-C` to cancel.

## Functions:

- `GitGrep(flags, pattern)` - issue a *git grep* command and open the selection menu,
  where *flags* are [git grep](https://git-scm.com/docs/git-grep) flags (can be empty string)
  and *pattern* is the pattern to look for.

- `GitGrepBack()` - jump back to previous location.

- `GitGrepIterPrev()` / `GitGrepIterNext()` - iterate to the previous/next match.

## Customizations:

- Change the default *git grep* command
```
let g:gitgrep_cmd = "grep -r"
```
- Jump automatically if there is one match or two matches (and cursor is already on one of those matches)
```
let g:gitgrep_auto_jump = 1
```
- Exclude files using Vim's regex
```
let g:gitgrep_exclude_files = "<regex>"
```
  E.g., exclude files stsarting witth `test` or containing `simulation`
```
let g:gitgrep_exclude_files = "^test\\|simulation"
```
- Set the height (number of lines) of the selection menu
```
let g:gitgrep_menu_height = 15
```
- Set the color of the file path
```
let g:gitgrep_file_color = "blue"
```
- Set the color of the matched pattern
```
let g:gitgrep_pattern_color = "red"
```
- Disable loading the plugin
```
let g:loaded_gitgrep = 1
```

## Mappings:

Keys are not mapped automatically. You can choose your own mapping,

Some recommendations:

Easily gitgrep for the word under cursor and jump back:
```
nnoremap <leader>g :call GitGrep("-w", expand("<cword>"))<CR>
nnoremap <leader>t :call GitGrepBack()<CR>
```

Create mappings with common grep flags:
```
command -bang -nargs=* GG call GitGrep("", expand(<q-args>))
command -bang -nargs=* GGw call GitGrep("-w", expand(<q-args>))
command -bang -nargs=* GGi call GitGrep("-i", expand(<q-args>))
```

Create mappings to iterate to the previous and next matches:
```
nnoremap <leader>p :call GitGrepIterPrev()<CR>
nnoremap <leader>n :call GitGrepIterNext()<CR>
```

### Examples:

Most basic usage - find all instances of "test":
```
:GG test
```

To use special characters such as space, escape the pattern:
```
:GG "def test"
```

Regex:
```
:GG def.*test
```

Additional grepping (can be used to filter files):
```
:GG def | grep test.py
```
