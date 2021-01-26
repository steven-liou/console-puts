" allows user to turn highlight on or off in settings
if !exists('g:console_puts_highlight')
  let g:console_puts_highlight = 1
endif

" allows user to set the time duration of highlight
if !exists('g:console_puts_highlight_timeout')
  let g:console_puts_highlight_timeout = 750
endif

highlight AddPrintLine guifg=#00ff00 ctermfg=Green
highlight RemovePrintLine guifg=#D16969 ctermfg=Red

" allowing operator motion to take numbers
function! s:SetupFunc()
    " stores the first number, before entering this motion, in script scope
    let s:first_count = v:count
    set operatorfunc=ConsolePutsOperator
    call s:Pick_print_options()
endfunction

" Get a list of possible print functions for current language type, join them together and output on screen

function! s:Pick_print_options() abort
  let print_function_names = s:Get_print_function_name()
  let print_function_names = add(print_function_names, 'Remove')
  let index = 0
  let options = ['Available option before operator motion: | ']
  for name in print_function_names
    call add(options, string(index + 1) . '.' . print_function_names[index] . ' | ')
    let index += 1
  endfor

  echom join(options, '')
endfunction

" Main function
function! ConsolePutsOperator(type) abort
  let print_option = s:Get_print_option(a:type)
  let [start_line, end_line] = s:Get_start_end_lines(a:type)
  call s:Toggle_print(a:type, start_line, end_line, print_option)
endfunction


" only allow user to use the number entered before the operator motion
function! s:Get_print_option(type) abort
  let s:second_count = v:count1

  let print_function_names = s:Get_print_function_name()
  
  " handles visual vs normal modes cases
  let print_option = a:type ==? 'v' ? s:second_count : s:first_count
  let print_option = print_option > 0 ? print_option : 1

  " return -1 if user selects an option not avilable, change option to 0 based index
  return print_option > len(print_function_names) ? -1 : print_option - 1
endfunction

function! s:Get_start_end_lines(type)
  " handles normal and visual mode selected line range numbers
  if (a:type ==# 'v' || a:type==# 'V')
    let start_line = line("'<")
    let end_line = line("'>")
  else
    let start_line = line("'[")
    let end_line = line("']")
  endif

  return [start_line, end_line]
endfunction 

function! s:Toggle_print(type, start_line, end_line, print_option) abort

  for line in range(a:start_line, a:end_line)
    let current_line_string = getline(line)
    if s:Invalid_line(current_line_string) | continue | endif
    
    if s:second_count !=# 1 && a:type !=? 'v'
      echom "Only number before operator motion is allowed. Retry."
    elseif (s:first_count > 0) && a:print_option !=# -1  " user specified valid option
      call s:Remove_print_function_in_line(line)
      call s:Add_print_function(line, a:print_option)
      if g:console_puts_highlight
        let lineID = matchaddpos('AddPrintLine', [line])
      endif
    elseif s:Has_print_function_in_line(current_line_string) !=# '' || a:print_option ==# -1  " if line has print function, remove it, else add it 
      if s:Has_print_function_in_line(current_line_string) !=# '' && g:console_puts_highlight
        let lineID = matchaddpos('RemovePrintLine', [line])
      endif
      call s:Remove_print_function_in_line(line)
    else
      call s:Add_print_function(line, a:print_option)
      if g:console_puts_highlight
        let lineID = matchaddpos('AddPrintLine', [line])
      endif
    endif

    " clear color highligh after given time
    if exists('lineID') && g:console_puts_highlight
      let Func = s:Create_clear_highlight(lineID)
      call timer_start(g:console_puts_highlight_timeout, Func)
      unlet lineID
    endif
  endfor
endfunction

function! s:Create_clear_highlight(id) abort
  let ClearHighlight = {id -> matchdelete(a:id)}
  return ClearHighlight
endfunction

function! s:Invalid_line(string) abort
  " an invalid line is blank, or starts with comment char
  if len(a:string) ==# 0 | return 1 | endif
  let comment_char = split(&commentstring, '%s')[0]
  if len(matchstr(a:string, '\v^\s*' . comment_char)) > 0 | return 1 | endif
  return 0
endfunction

function! s:Get_print_function_name() abort
  let print_function_dict = {
        \ 'javascript' : ['console.log'],
        \ 'python' : ['print'],
        \ 'ruby' : ['puts', 'p', 'print'],
        \ 'vim' : ['echom', 'echo'],
        \ }
  return print_function_dict[&filetype]
endfunction


function! s:Has_print_function_in_line(string) abort
  let print_function_name = s:Get_print_function_name()

  for name in print_function_name
    let match_string = '\v^\s*' . name . '[ (]'

    if (match(a:string, match_string) !=# -1)
      return name
    endif
  endfor
  return ''
endfunction

function s:Get_string_parts(string, add_comment) abort
  let leading_spaces = matchstr(a:string, '\v^\s*')
  let trimmed_string = a:string[len(leading_spaces):]
  let trimmed_string = substitute(trimmed_string, '\v\s*$', '', 'e') " remove trailing white spaces

  let comment_char = split(&commentstring, '%s')[0]
  let noise_chars_pattern = join(s:Noise_chars(), '|')
  " The pattern look from the back of the trimmed string. It first looks for noise chars after valid code, then empty space. If match, it looks beforehand 1 char and check if it is a ; or a space
  " The idea is to check at least a ; or a space before the noise or comment char to distinguish the valid code and the comment parts in the line
  let comment_regex = '\v(;|\s)@<=(' . noise_chars_pattern . '|\s|' . comment_char . ').{-}$' 
  let comment_string = matchstr(trimmed_string, comment_regex)
  let empty_comment_string = substitute(comment_string, '\v^\s*', '', 'e')
  if empty_comment_string ==# ''
    let comment_string = ''
  end
  let comment_string_length = len(comment_string)
 

  " if comment part doesn't start with the comment char
  if match(comment_string, '\v^\s*' . comment_char) ==# -1 && comment_string_length > 0 && a:add_comment
    " remotve existing comment char if exists
    if match(comment_string, '\v' . comment_char) !=# -1
      let comment_string = substitute(comment_string, '\v' . comment_char, '', 'e')
    endif
    
    " if comment char already has padding, don't add another space
    let comment_padding = comment_char[len(comment_char) - 1] ==# ' ' ? '' : ' '
    " Add the comment char in front, decide on whether first char is a space already
    if comment_string[0] !=# ' ' 
      let comment_string = ' ' . comment_char . comment_padding . comment_string
    else
      let comment_string = comment_char . comment_padding . comment_string
    endif
  else
    if comment_string[0] !=# ' ' && comment_string_length > 0
      let comment_string = ' ' . comment_string
    endif
  endif


  " Get the content string
  if len(comment_string) > 0 
    let content_string = trimmed_string[:-(comment_string_length + 1)]
    let content_string = content_string[len(content_string) - 1] ==# ' ' ? content_string[:-2] : content_string
  else
    let content_string = trimmed_string
  endif

  return [leading_spaces, content_string, comment_string]
endfunction

function! s:Noise_chars() abort
  " noise characters are symbols that some problems from online like to put in front of test cases expected results. The goal is to match those noise chars and move/place the comment char infront of them if they exist
  return ['⇉', '⇆', '↔', '⇨', '↔', '⇾', '➞', '\-+\>', '\~+\>', '\>+']
endfunction

function! s:Add_print_function(line_number, print_option) abort
  let string = getline(a:line_number)
  let [leading_spaces, content_string, comment_string] = s:Get_string_parts(string, 1)
  let [open_delimiter, close_delimiter] = s:Function_call_delimiters()


  " build the original content string wrapped by the print function, i.e. the expression to be printed
  let end_line_delimiter = s:End_line_delimiters()
  let end_line_delimiter_index = match(content_string, '\v' . end_line_delimiter . '\s*$')
  if end_line_delimiter_index !=# -1 
    " for programming languages that use semi colon to signify end of code line
    let content_string = open_delimiter . content_string[:end_line_delimiter_index - 1] . close_delimiter . end_line_delimiter
  else
    let content_string = open_delimiter . content_string . close_delimiter 
    if len(comment_string) > 0
      let content_string = content_string . ' '
    endif
  endif
  
  " get the print function name chosen by user, build the final line, and replace the current line with the result
  let print_function_names = s:Get_print_function_name()
  let print_function = get(print_function_names, a:print_option, print_function_names[0])
  let result_content = leading_spaces . print_function . content_string  . comment_string
  " let result_content = substitute(result_content, '\v\s*$', '', 'e')  " trim trailing empty spaces 
  call setline(a:line_number, result_content)
endfunction

function! s:End_line_delimiters() abort
  let end_line_delimiter_dict = {
        \ 'javascript' : ';',
        \ 'python' : ';',
        \ 'ruby' : ';',
        \ 'vim' : ';',
        \ }
  return end_line_delimiter_dict[&filetype]
endfunction

function! s:Function_call_delimiters() abort
  let function_call_delimiter_dict = {
        \ 'javascript' : ['(', ')'],
        \ 'python' : ['(', ')'],
        \ 'ruby' : [' ', ''],
        \ 'vim' : [' ', ''],
        \ }
  return function_call_delimiter_dict[&filetype]
endfunction

function! s:Remove_print_function_in_line(line_number) abort
  let string = getline(a:line_number)
  let [leading_spaces, content_string, comment_string] = s:Get_string_parts(string, 0)
  let print_regex_part = '\v^' . s:Has_print_function_in_line(content_string)

  let removed_print_function_content = substitute(content_string, print_regex_part, '', 'e')
  
  " clean up the print function's parentheses if exist
  let [open_delimiter, close_delimiter] = s:Function_call_delimiters()
  if removed_print_function_content[0] ==# '('
    let removed_print_array = split(removed_print_function_content, '\zs')
    let last_close_paren_index = len(removed_print_array) - index(reverse(copy(removed_print_array)), ')') - 1
    let removed_delimiter_content = join(removed_print_array[1:last_close_paren_index - 1] + removed_print_array[last_close_paren_index + 1 :], '')
  elseif removed_print_function_content[0] ==# ' '  " for languages that don't use parentheses for function call
    let removed_delimiter_content = removed_print_function_content[1:]
  else
    let removed_delimiter_content = removed_print_function_content
  endif

  " build the result string and replace current line with it
  let result_content =  leading_spaces . removed_delimiter_content . comment_string
  call setline(a:line_number, result_content)
 endfunction


" Code for mappings
nnoremap <silent> <Plug>ConsolePutsNormal :<C-u>call <SID>SetupFunc()<CR>g@
xnoremap <silent> <Plug>ConsolePutsVisual :<C-u>call <SID>SetupFunc()\|call ConsolePutsOperator(visualmode())<CR>

if !exists('g:console_puts_mapping')
  let g:console_puts_mapping = 1
endif

if g:console_puts_mapping
  nmap cp <Plug>ConsolePutsNormal
  vmap cp <Plug>ConsolePutsVisual
elseif exists('g:console_puts_motion')
  execute 'nmap ' . g:console_puts_motion . ' <Plug>ConsolePutsNormal'
  execute 'vmap ' . g:console_puts_motion . ' <Plug>ConsolePutsVisual'
endif



