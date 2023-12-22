" Vim global plugin for using git grep
" Last Change:  2023 Aug 11
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
" Also contains the auto-jump logic.
function s:Grep(flags, pattern)
  " settings
  let l:gitgrep_cmd = get(g:, 'gitgrep_cmd', 'git grep')
  let l:gitgrep_exclude_files = get(g:, 'gitgrep_exclude_files', '')
  let l:gitgrep_auto_jump = get(g:, 'gitgrep_auto_jump', 0)

  let l:cmd = l:gitgrep_cmd . " -n " . a:flags . " " . a:pattern
  let l:options = systemlist(l:cmd)

  if v:shell_error == 1
    echo "No match found"
    return [0, v:null]
  endif

  if v:shell_error != 0
    echo "Not a git repository"
    return [0, v:null]
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
      return [0, v:null]
    endif
  endif

  let l:selected_line = ""
  let l:line_num = v:null
  if l:gitgrep_auto_jump == 1
    if len(l:options) == 1
      let l:selected_line = l:options[0]
      let l:line_num = 0
      let l:file_and_line = s:ParseFileAndLineNo(l:selected_line)
      let l:full_filename = fnamemodify(l:file_and_line[0], ':p')
      if l:full_filename == expand('%:p') && l:file_and_line[1] == line(".")
        echo "Already on single match"
        return [0, v:null]
      endif
    elseif len(l:options) == 2
      let l:file_and_line = s:ParseFileAndLineNo(l:options[0])
      let l:full_filename = fnamemodify(l:file_and_line[0], ':p')
      if l:full_filename == expand('%:p') && l:file_and_line[1] == line(".")
        let l:selected_line = l:options[1]
        let l:line_num = 1
      else
        let l:file_and_line = s:ParseFileAndLineNo(l:options[1])
        let l:full_filename = fnamemodify(l:file_and_line[0], ':p')
        if l:full_filename == expand('%:p') && l:file_and_line[1] == line(".")
          let l:selected_line = l:options[0]
          let l:line_num = 0
        endif
      endif
    endif
  endif
  let l:prompt = l:cmd . " (" . len(l:options) . " matches)"
  return [1, [l:options, l:selected_line, l:line_num, l:prompt]]
endfunction


function s:CloseBuffer(bufnr)
  wincmd p
  execute "bwipe" a:bufnr
  redraw
  return ""
endfunction


function s:InteractiveMenu(input, prompt, pattern) abort
  bo new +setlocal\ buftype=nofile\ bufhidden=wipe\ nofoldenable\
    \ colorcolumn=0\ nobuflisted\ number\ norelativenumber\ noswapfile\ wrap\ cursorline

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
      let l:line_num = line('.')
      call s:CloseBuffer(l:cur_buf)
      return [l:result, l:line_num - 1]
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
  let l:res = s:Grep(a:flags, a:pattern)
  if !l:res[0]
    return
  endif

  let l:options = res[1][0]
  let l:selected_line = res[1][1]
  let l:line_num = res[1][2]
  let l:prompt = res[1][3]

  " user selection
  if empty(l:selected_line)
    let l:selected_line_and_index = s:InteractiveMenu(l:options, l:prompt, a:pattern)
    if empty(l:selected_line_and_index)
      return
    endif
    let l:selected_line = l:selected_line_and_index[0]
    let l:line_num = l:selected_line_and_index[1]
  endif

  " store information to allow iteration
  let s:iter_matches = l:options
  let s:iter_index = l:line_num

  " store previous location to allow jumping back
  call add(s:prev_locations, [line("."), expand('%:p')])

  " process selection
  let l:splitted_line = split(l:selected_line, ":")
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
