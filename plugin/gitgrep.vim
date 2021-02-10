" File: gitgrep.vim - script to git grep a pattern across a git repository
" Author: Eran Friedman

let g:gitgrep_menu_height = 15

function GG_CloseBuffer(bufnr)
   wincmd p
   execute "bwipe" a:bufnr
   redraw
   return ""
endfunction

function GG_InteractiveMenu(input, prompt, pattern) abort
  bo new +setlocal\ buftype=nofile\ bufhidden=wipe\ nofoldenable\
    \ colorcolumn=0\ nobuflisted\ number\ norelativenumber\ noswapfile\ nowrap\ cursorline

  highlight filename_group ctermfg=blue
  highlight pattern_group ctermfg=red
  match filename_group /^.*:\d\+:/
  call matchadd("pattern_group", a:pattern[1:-2]) " remove shellescape from pattern

  let l:cur_buf = bufnr('%')
  call setline(1, a:input)
  exe "res " . g:gitgrep_menu_height
  redraw
  echo a:prompt

  while 1
    try
      let ch = getchar()
    catch /^Vim:Interrupt$/ " CTRL-C
      return GG_CloseBuffer(l:cur_buf)
    endtry

    if ch ==# 0x1B " ESC
      return GG_CloseBuffer(l:cur_buf)
    elseif ch ==# 0x0D " Enter
      let l:result = getline('.')
      call GG_CloseBuffer(l:cur_buf)
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
      for i in range(1, g:gitgrep_menu_height)
        norm k
      endfor
    elseif ch == "\<PageDown>"
      for i in range(1, g:gitgrep_menu_height)
        norm j
      endfor
    endif

    redraw
  endwhile
endfunction

" Git grepping for pattern
function GitGrep(flags, pattern)
  let l:pattern = shellescape(a:pattern)
  let l:cmd = "git grep -n " . a:flags . " " . l:pattern
  let l:options = systemlist(l:cmd)

  if v:shell_error == 1
      echo "No match found"
      return
  endif

  if v:shell_error != 0
      echo "Not a git repository"
      return
  endif

  " user selection
  let l:prompt = l:cmd . " (" . len(l:options) . " matches)"
  let l:selected_line = GG_InteractiveMenu(l:options, l:prompt, l:pattern)
  if empty(l:selected_line)
    return
  endif

  " process selection
  let l:splitted_line = split(l:selected_line, ":")
  let l:filename = l:splitted_line[0]
  let l:line_no = l:splitted_line[1]

  " store previous location to allow jumping back
  let s:prev_file = expand('%:p')
  let s:prev_line_no = line(".")

  " jump to selection
  execute 'edit +' . l:line_no l:filename
endfunction

" Jump back to previous location
function GitGrep_PrevLocation()
  try
    execute 'edit +' . s:prev_line_no s:prev_file
  catch
    echo "No previous location"
  endtry
endfunction
