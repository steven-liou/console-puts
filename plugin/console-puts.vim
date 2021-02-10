" allows user to turn highlight on or off in settings
if !exists('g:console_puts_highlight')
  let g:console_puts_highlight = 1
endif

" allows user to set the time duration of highlight
if !exists('g:console_puts_highlight_timeout')
  let g:console_puts_highlight_timeout = 750
endif

" for allowing user to set custom highlightings
if !hlexists('AddPrintLine')
  highlight AddPrintLine guifg=#00ff00 ctermfg=Green
endif

if !hlexists('RemovePrintLine')
  highlight RemovePrintLine guifg=#D16969 ctermfg=Red
endif

" allowing operator motion to take numbers
function! s:SetupFunc() abort
    " stores the first motion number, before entering this motion, in script scope
    let s:first_count = v:count
    set operatorfunc=ConsolePutsOperator
    call s:Print_options()
endfunction


" Get a list of possible print functions for current language type, join them together and output on screen
function! s:Print_options() abort
  let print_function_names = copy(s:Get_print_function_name())
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

function! s:Get_start_end_lines(type) abort
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
    
    if (s:first_count > 0) && a:print_option !=# -1  " user specified valid option that adds print function
      call s:Option_print_helper(line, current_line_string, a:print_option)
    elseif s:Has_print_function_in_line(current_line_string) !=# '' || a:print_option ==# -1  " if line has print function, remove it, else add print function 
      call s:Remove_print_helper(line, current_line_string)
    else
      call s:Add_print_helper(line, current_line_string, a:print_option)
    endif
  endfor
endfunction

function! s:Invalid_line(string) abort
  " an invalid line is blank, or starts with comment char
  if len(a:string) ==# 0 | return 1 | endif
  let comment_char = split(&commentstring, '%s')[0]
  if len(matchstr(a:string, '\v^\s*' . comment_char)) > 0 | return 1 | endif
  return 0
endfunction

function! s:Clear_highlight(id) abort
  let Func = {-> matchdelete(a:id)}
  call timer_start(g:console_puts_highlight_timeout, Func)
endfunction

" The helper functions that set the line with final results, and handle logic for whether to highlight the toggling actions
function! s:Option_print_helper(line, current_line_string, option) abort
  let removed_print_line = s:Remove_print_function_in_line(a:current_line_string)
  let added_print_line = s:Add_print_function(removed_print_line, a:option)
  call setline(a:line, added_print_line)

  if g:console_puts_highlight
    let lineID = matchaddpos('AddPrintLine', [a:line])
    call s:Clear_highlight(lineID)
  endif
endfunction

function! s:Remove_print_helper(line, current_line_string) abort
  call setline(a:line, s:Remove_print_function_in_line(a:current_line_string))

  if s:Has_print_function_in_line(a:current_line_string) !=# '' && g:console_puts_highlight
    let lineID = matchaddpos('RemovePrintLine', [a:line])
    call s:Clear_highlight(lineID)
  endif
endfunction

function! s:Add_print_helper(line, current_line_string, option) abort
  call setline(a:line, s:Add_print_function(a:current_line_string, a:option))
  if g:console_puts_highlight
    let lineID = matchaddpos('AddPrintLine', [a:line])
    call s:Clear_highlight(lineID)
  endif
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

function! s:Get_string_parts(string, add_comment) abort
  let leading_spaces = matchstr(a:string, '\v^\s*')
  let trimmed_string = a:string[len(leading_spaces):]
  let trimmed_string = substitute(trimmed_string, '\v\s*$', '', 'e') " remove trailing white spaces

  let comment_string = s:Get_comment_part(trimmed_string, a:add_comment)
  let comment_string_length = len(comment_string)

  let comment_char = split(&commentstring, '%s')[0]
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
      let comment_string = ' ' . comment_char . comment_padding . comment_string[1:]
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
    let content_string = substitute(content_string, '\v\s*$', '', 'e')  " remove trailing white spaces
  else
    let content_string = trimmed_string
  endif

  return [leading_spaces, content_string, comment_string]
endfunction

function! s:Get_comment_part(trimmed_string, add_comment) abort
  let end_line_delimiter = s:End_line_delimiters()
  let noise_chars_pattern = join(s:Noise_chars(), '|')
  let comment_char = split(&commentstring, '%s')[0]
  let start_comment_chars = end_line_delimiter . '|' . noise_chars_pattern . '|' . comment_char . '|\s{2,}' 

  let trimmed_string = s:Clean_string_literal(a:trimmed_string, start_comment_chars)

  " if the string has EOL delimiter that is not a space, the comment part is everything after it
  if end_line_delimiter != '\s' && match(trimmed_string, end_line_delimiter) !=# -1
    return matchstr(trimmed_string, '\v(' . end_line_delimiter . ')@<=.*$')
  endif

  " if the string has noise characters, the comment part is noise characters plus everything after it
  let comment_char_index = match(trimmed_string, comment_char)
  let comment_char_index = comment_char_index ==# -1 ? 10000 : comment_char_index 
  let noise_char_index = match(trimmed_string, '\v' . noise_chars_pattern)

  if noise_char_index !=# -1 &&  noise_char_index < comment_char_index
    return matchstr(trimmed_string, '\v(' . noise_chars_pattern . ').*$')
  endif

  " handles lines with consecutive spaces
  if match(trimmed_string, '\v' . s:white_spaces) !=# -1
    return matchstr(trimmed_string, '\v(' . s:white_spaces .')@<=.{-}$')
  endif

  " handles comment chars
  if match(trimmed_string, comment_char) !=# -1
    return matchstr(trimmed_string, '\v' . comment_char . '.{-}$' )
  endif

  return ''
endfunction

function! s:Clean_string_literal(string, remove_string_chars) abort
  let chars_regex = '\v(' . a:remove_string_chars . ')'

  " logics for finding the first start of comment chars index that is not in a single or double quote
  let start_comment_index = 0
  let check_index = 0
  let start_quote_index = 0
  let end_quote_index = -1
  
  while match(a:string, chars_regex, check_index) !=# -1
    let matched_index = match(a:string, chars_regex, check_index)
    let matched_chars = matchstr(a:string, chars_regex, check_index)

    let end_quote_index = matched_index < end_quote_index ? start_quote_index - 1 : end_quote_index

    let start_quote_index = match(a:string, '\v[''"]', end_quote_index + 1)
    let end_quote_index = match(a:string, '\v[''"]', start_quote_index + 1)

    if start_quote_index < matched_index && matched_index < end_quote_index
      let check_index = matched_index + len(matched_chars)
    else
      let start_comment_index = matched_index 
      break
    endif
  endwhile

  if start_comment_index
    let content_string = a:string[0:start_comment_index - 1]
    let comment_string = a:string[start_comment_index:]
  else 
    let content_string = a:string
    let comment_string = '' 
  endif

  let in_quote_chars_regex = '\v([''"][^''"]*)@<=(' . a:remove_string_chars . ')([^''"]*[''"])@='  " looking behind and forward to see the matched white spaces, EOL delimiters, comment chars, or noise characters are within single or double quotes

  " remove start of comment characters in quotes only for the part of line that is not comment 
  let trimmed_content_string = substitute(content_string, in_quote_chars_regex, '', 'ge')
  return trimmed_content_string . comment_string
endfunction

function! s:Add_print_function(string, print_option) abort
  let [leading_spaces, content_string, comment_string] = s:Get_string_parts(a:string, 1)
  let content_string = s:Add_print_content_string(content_string, len(comment_string))
  
  " get the print function name chosen by user, build the final line, and replace the current line with the result
  let print_function_names = s:Get_print_function_name()
  let print_function = get(print_function_names, a:print_option, print_function_names[0])
  let result_content = leading_spaces . print_function . content_string  . comment_string
  return result_content
endfunction

" build the original content string wrapped by the print function, i.e. the expression to be printed
function! s:Add_print_content_string(content_string, comment_string_length) abort
  let [open_delimiter, close_delimiter] = s:Function_call_delimiters()
  let end_line_delimiter = s:End_line_delimiters()
  let end_line_delimiter_index = match(a:content_string, '\v' . end_line_delimiter . '\s*$')

  " for programming languages that use semi colon to signify end of code line
  if end_line_delimiter_index !=# -1 
    let content_string = open_delimiter . a:content_string[:end_line_delimiter_index - 1] . close_delimiter . end_line_delimiter
  else 
    let content_string = open_delimiter . a:content_string . close_delimiter 
    if a:comment_string_length > 0   " add a space padding if there is comment after the content
      let content_string = content_string . ' '
    endif
  endif

  return content_string
endfunction

function! s:Remove_print_function_in_line(string) abort
  let [leading_spaces, content_string, comment_string] = s:Get_string_parts(a:string, 0)
  let removed_print_content_string = s:Remove_print_content_string(content_string)

  " build the result string and replace current line with it
  let result_content = leading_spaces . removed_print_content_string . comment_string
  return result_content
endfunction

function! s:Remove_print_content_string(content_string) abort
  let print_regex_part = '\v^' . s:Has_print_function_in_line(a:content_string)
  let removed_print_function_content = substitute(a:content_string, print_regex_part, '', 'e')
  
  " clean up the print function's parentheses if exist
  let [open_delimiter, close_delimiter] = s:Function_call_delimiters()

  if open_delimiter !=# ' ' " for languages that use open-close delimiter, typically parentheses, for function calls
    let removed_print_array = split(removed_print_function_content, '\zs')
    let last_close_paren_index = len(removed_print_array) - index(reverse(copy(removed_print_array)), close_delimiter ) - 1
    let removed_delimiter_content = join(removed_print_array[1:last_close_paren_index - 1] + removed_print_array[last_close_paren_index + 1 :], '')
  else  " for languages that don't use parentheses for function call
    let removed_delimiter_content = removed_print_function_content[1:]
  " else
  "   let removed_delimiter_content = removed_print_function_content
  endif

  let end_line_delimiter = s:End_line_delimiters()
  if removed_delimiter_content[len(removed_delimiter_content) - 1] !=# end_line_delimiter
    let removed_delimiter_content = removed_delimiter_content . ' '
  endif

  return removed_delimiter_content
endfunction


" Allow the user to specify print function names for a programming language
let s:print_function_dict = {
      \ 'go' : ['fmt.Println', 'fmt.Print'],
      \ 'javascript' : ['console.log'],
      \ 'python' : ['print'],
      \ 'ruby' : ['puts', 'p', 'print'],
      \ 'vim' : ['echom', 'echo'],
      \ }

if exists('g:print_functions')
  for [language, print_function] in items(g:print_functions)
    let s:print_function_dict[language] = print_function
  endfor
endif

function! s:Get_print_function_name() abort
  return get(s:print_function_dict, &filetype, [''])
endfunction


" Allow the user to specify end of line delimiters for a programming language, default is ';'
let s:end_line_delimiter_dict = {
      \ 'go' : ';',
      \ 'javascript' : ';',
      \ 'python' : ';',
      \ 'ruby' : ';',
      \ 'vim' : ';',
      \ }

if exists('g:end_line_delimiters') 
  for [language, end_line_delimiter] in items(g:end_line_delimiters)
    let s:end_line_delimiter_dict[language] = end_line_delimiter
  endfor
endif

function! s:End_line_delimiters() abort
  return get(s:end_line_delimiter_dict, &filetype, ';')
endfunction

" allows the user to spcify the function call delimiters for a programming language, default is '( and )'
let s:function_call_delimiter_dict = {
      \ 'go' : ['(', ')'],
      \ 'javascript' : ['(', ')'],
      \ 'python' : ['(', ')'],
      \ 'ruby' : [' ', ''],
      \ 'vim' : [' ', ''],
      \ }

if exists('g:function_call_delimiters')
  for [language, delimiters] in items(g:function_call_delimiters)
    let s:function_call_delimiter_dict[language] = delimiters
  endfor
endif

function! s:Function_call_delimiters() abort
  return get(s:function_call_delimiter_dict, &filetype, ['(', ')'])
endfunction


" allows the user to specify noise characters to comment out
let s:noise_chars_dict = {
      \ 'general' :['⇉+', '⇆+', '↔+', '⇨+', '↔+', '⇾+', '➞+', '\-+\>', '\~+\>', '\>{2,}'],
      \ }

if exists('g:noise_chars') 
  for [language, delimiters] in items(g:noise_chars)
    let s:noise_chars_dict[language] = delimiters
  endfor
endif

" allows the user to specify minimum number of consecutive white spaces to automatically comment out
if exists('g:cp_minimum_consecutive_spaces')
  let s:consecutive_spaces_number = g:cp_minimum_consecutive_spaces
else
  let s:consecutive_spaces_number = 2
end
let s:white_spaces = '\s{' . string(s:consecutive_spaces_number) . ',}'

function! s:Noise_chars() abort
  " noise characters are symbols that some problems from online like to put in front of test cases expected results. The goal is to match those noise chars and move/place the comment char infront of them if they exist
  return s:noise_chars_dict['general'] + get(s:noise_chars_dict, &filetype, [])
endfunction

" Code for mappings
nnoremap <silent> <Plug>ConsolePutsNormal :<C-u>call <SID>SetupFunc()<CR>g@
xnoremap <silent> <Plug>ConsolePutsVisual :<C-u>call <SID>SetupFunc()\|call ConsolePutsOperator(visualmode())<CR>

if !exists('g:console_puts_mapping')
  let g:console_puts_mapping = 1
endif

if g:console_puts_mapping
  vmap cp <Plug>ConsolePutsVisual
  nmap cp <Plug>ConsolePutsNormal
endif

