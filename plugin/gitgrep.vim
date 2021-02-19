" Vim global plugin for using git grep
" Last Change:  2021 Feb 19
" Maintainer:   Eran Friedman
" License:      This file is placed in the public domain.


let s:save_cpo = &cpo
set cpo&vim


let s:prev_locations = []


function s:CloseBuffer(bufnr)
   wincmd p
   execute "bwipe" a:bufnr
   redraw
   return ""
endfunction

function s:InteractiveMenu(input, prompt, pattern) abort
  bo new +setlocal\ buftype=nofile\ bufhidden=wipe\ nofoldenable\
    \ colorcolumn=0\ nobuflisted\ number\ norelativenumber\ noswapfile\ nowrap\ cursorline

  " settings
  let l:gitgrep_menu_height = get(g:, 'gitgrep_menu_height', 15)
  let l:gitgrep_file_color = get(g:, 'gitgrep_file_color', "blue")
  let l:gitgrep_pattern_color = get(g:, 'gitgrep_pattern_color', "red")

  exe 'highlight filename_group ctermfg=' . l:gitgrep_file_color
  exe 'highlight pattern_group ctermfg=' . l:gitgrep_pattern_color
  match filename_group /^.*:\d\+:/
  call matchadd("pattern_group", a:pattern[1:-2]) " remove shellescape from pattern

  let l:cur_buf = bufnr('%')
  call setline(1, a:input)
  exe "res " . l:gitgrep_menu_height
  redraw
  echo a:prompt

  while 1
    try
      let ch = getchar()
    catch /^Vim:Interrupt$/ " CTRL-C
      return s:CloseBuffer(l:cur_buf)
    endtry

    if ch ==# 0x1B " ESC
      return s:CloseBuffer(l:cur_buf)
    elseif ch ==# 0x0D " Enter
      let l:result = getline('.')
      call s:CloseBuffer(l:cur_buf)
      return l:result
    elseif ch ==# 0x6B " k
      norm k
    elseif ch ==# 0x6A " j
      norm j
    elseif ch == "\<Up>"
      norm k
    elseif ch == "\<Down>"
      norm j
    elseif ch == "\<PageUp>"
      for i in range(1, l:gitgrep_menu_height)
        norm k
      endfor
    elseif ch == "\<PageDown>"
      for i in range(1, l:gitgrep_menu_height)
        norm j
      endfor
    endif

    redraw
  endwhile
endfunction

" Git grepping for pattern
function GitGrep(flags, pattern)
  " settings
  let l:gitgrep_cmd = get(g:, 'gitgrep_cmd', 'git grep')
  let l:gitgrep_exclude_files = get(g:, 'gitgrep_exclude_files', '')

  let l:pattern = shellescape(a:pattern)
  let l:cmd = l:gitgrep_cmd . " -n " . a:flags . " " . l:pattern
  let l:options = systemlist(l:cmd)

  if v:shell_error == 1
      echo "No match found"
      return
  endif

  if v:shell_error != 0
      echo "Not a git repository"
      return
  endif

  " filter files
  if !empty(l:gitgrep_exclude_files)
    let l:filtered_options = []
    for i in range(0, len(l:options) - 1)
      let l:filename = split(l:options[i], ":")[0]
      let result = matchstr(l:filename, l:gitgrep_exclude_files)
      if empty(result)
        call add(l:filtered_options, l:options[i])
      endif
    endfor
    let l:options = l:filtered_options
    " check if list is empty after filtering
    if len(l:options) == 0
      echo "No match found"
      return
    endif
  endif

  " user selection
  let l:prompt = l:cmd . " (" . len(l:options) . " matches)"
  let l:selected_line = s:InteractiveMenu(l:options, l:prompt, l:pattern)
  if empty(l:selected_line)
    return
  endif

  " process selection
  let l:splitted_line = split(l:selected_line, ":")
  let l:filename = l:splitted_line[0]
  let l:line_no = l:splitted_line[1]

  " store previous location to allow jumping back
  call add(s:prev_locations, [line("."), expand('%:p')])

  " jump to selection
  execute 'edit +' . l:line_no l:filename
endfunction

" Jump back to previous location
function GitGrepBack()
  if empty(s:prev_locations)
    echo "No previous location"
    return
  endif

  let l:prev_loc = remove(s:prev_locations, -1)
  execute 'edit +' . l:prev_loc[0] l:prev_loc[1]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
