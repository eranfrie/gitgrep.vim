" Vim global plugin for using git grep
" Last Change:  2023 Dec 23
" Maintainer:   Eran Friedman
" License:      This file is placed in the public domain.


if exists("g:loaded_gitgrep")
  finish
endif
let g:loaded_gitgrep = 1


let s:save_cpo = &cpo
set cpo&vim


let s:prev_locations = []

" iterating matches
let s:iter_matches = v:null
let s:iter_index = 0


" Execute the grep command.
function s:Grep(flags, pattern) abort
  " settings
  let l:gitgrep_cmd = get(g:, 'gitgrep_cmd', 'git grep')
  let l:gitgrep_exclude_files = get(g:, 'gitgrep_exclude_files', '')

  let l:cmd = l:gitgrep_cmd . " -n " . a:flags . " " . a:pattern
  let l:options = systemlist(l:cmd)
  let l:prompt = l:cmd . " (0 matches)"

  " pattern is empty - nothing to run
  if empty(a:pattern)
    return [1, [], l:prompt]
  endif

  " probably not a real error, but no match is found
  if v:shell_error == 1
    return [1, [], l:prompt]
  endif

  if v:shell_error != 0
    echo "Not a git repository"
    return [0, v:null, l:prompt]
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
      return [1, [], l:prompt]
    endif
  endif

  let l:prompt = l:cmd . " (" . len(l:options) . " matches)"
  return [1, l:options, l:prompt]
endfunction


function s:CloseBuffer(bufnr)
  wincmd p
  execute "bwipe" a:bufnr
  redraw
endfunction


function s:InteractiveMenu(flags, pattern) abort
  let l:pattern = a:pattern

  " settings
  let l:gitgrep_menu_height = get(g:, 'gitgrep_menu_height', 15)
  let l:gitgrep_file_color = get(g:, 'gitgrep_file_color', "blue")
  let l:gitgrep_pattern_color = get(g:, 'gitgrep_pattern_color', "red")

  bo new +setlocal\ buftype=nofile\ bufhidden=wipe\ nofoldenable\
    \ colorcolumn=0\ nobuflisted\ number\ norelativenumber\ noswapfile\ wrap\ cursorline

  exe 'highlight filename_group ctermfg=' . l:gitgrep_file_color
  match filename_group /^.*:\d\+:/
  exe 'highlight pattern_group ctermfg=' . l:gitgrep_pattern_color
  " refresh coloring of the matched pattern
  let l:pattern_to_color = l:pattern
  if len(l:pattern) > 2 && l:pattern[0] == "'"
    let l:pattern_to_color = l:pattern[1:-2]
  endif
  let l:pattern_coloring_id = matchadd("pattern_group", l:pattern_to_color)

  let l:res = s:Grep(a:flags, l:pattern)
  if l:res[0] == 0
    return [0, v:null, v:null, v:null]
  endif

  let l:options = res[1]
  let l:prompt = res[2]

  let l:cur_buf = bufnr('%')
  call setline(1, l:options)
  exe "res " . l:gitgrep_menu_height
  redraw
  echo l:prompt

  while 1
    try
      let ch = getchar()
    catch /^Vim:Interrupt$/ " CTRL-C
      call s:CloseBuffer(l:cur_buf)
      return [0, v:null, v:null, v:null]
    endtry

    if ch ==# 0x1B " ESC
      call s:CloseBuffer(l:cur_buf)
      return [0, v:null, v:null, v:null]
    elseif ch ==# 0x0D " Enter
      let l:selected_line = getline('.')
      let l:line_num = line('.')
      call s:CloseBuffer(l:cur_buf)
      return [1, l:selected_line, l:line_num - 1, l:options]
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
    " update pattern
    else
      " Backspace
      if ch is# "\<BS>"
        if len(l:pattern) > 0
          " preserve encapsulation
          if l:pattern[0] == "'"
            let l:pattern = l:pattern[:-2]
            if len(l:pattern) > 1
              let l:pattern = l:pattern[:-2]
            endif
            let l:pattern = l:pattern . "'"
          else
            let l:pattern = l:pattern[:-2]
          endif
        endif
      " concatenate a character
      else
        " preserve encapsulation
        if l:pattern[0] == "'"
          let l:pattern = l:pattern[:-2]
          let l:pattern = l:pattern . nr2char(ch)
          let l:pattern = l:pattern . "'"
        else
          let l:pattern = l:pattern . nr2char(ch)
        endif
      endif

      let l:res = s:Grep(a:flags, l:pattern)
      " remove all lines in case there are less options than before
      let l:lines_to_remove = len(l:options)
      while l:lines_to_remove > 0
        d
        let l:lines_to_remove -=1
      endwhile

      let l:options = res[1]
      let l:prompt = res[2]

      let l:cur_buf = bufnr('%')
      call setline(1, l:options)

      " refresh coloring of the matched pattern
      let l:pattern_to_color = l:pattern
      if len(l:pattern) > 2 && l:pattern[0] == "'"
        let l:pattern_to_color = l:pattern[1:-2]
      endif
      call matchdelete(l:pattern_coloring_id)
      let l:pattern_coloring_id = matchadd("pattern_group", l:pattern_to_color)

      exe "res " . l:gitgrep_menu_height

    endif

    redraw
    echo l:prompt

  endwhile
endfunction


" format of line is <file>:<line number>:...
function s:ParseFileAndLineNo(line)
  let l:splitted_line = split(a:line, ":")
  let l:filename = l:splitted_line[0]
  let l:line_no = l:splitted_line[1]
  return [l:filename, l:line_no]
endfunction


" iterate to the orevious match
function GitGrepIterPrev()
  if s:iter_matches is v:null
    echo "No matches to iterate"
    return
  endif
  if s:iter_index - 1 == -1
    echo "This is the first match"
    return
  endif

  let s:iter_index -= 1
  let l:file_and_lineno = s:ParseFileAndLineNo(s:iter_matches[s:iter_index])
  let l:filename = l:file_and_lineno[0]
  let l:line_no = l:file_and_lineno[1]
  execute 'edit +' . l:line_no l:filename
endfunction


" iterate to the next match
function GitGrepIterNext()
  if s:iter_matches is v:null
    echo "No matches to iterate"
    return
  endif
  if s:iter_index + 1 == len(s:iter_matches)
    echo "This is the last match"
    return
  endif

  let s:iter_index += 1
  let l:file_and_lineno = s:ParseFileAndLineNo(s:iter_matches[s:iter_index])
  let l:filename = l:file_and_lineno[0]
  let l:line_no = l:file_and_lineno[1]
  execute 'edit +' . l:line_no l:filename
endfunction


" Git grepping for pattern
function GitGrep(flags, pattern)
  let res = s:InteractiveMenu(a:flags, a:pattern)
  if res[0] == 0 || res[1] == v:null
    return
  endif

  let l:selected_line = res[1]
  let l:line_num = res[2]
  let l:options = res[3]

  " store information to allow iteration
  let s:iter_matches = l:options
  let s:iter_index = l:line_num

  " store previous location to allow jumping back
  call add(s:prev_locations, [line("."), expand('%:p')])

  " process selection
  let l:splitted_line = split(l:selected_line, ":")
  " can be <2 if the list of options is empty and Enter is pressed
  if len(l:splitted_line) < 2
    return
  endif
  let l:filename = l:splitted_line[0]
  let l:line_no = l:splitted_line[1]

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
