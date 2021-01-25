# Console-Puts
---
## Motivations for the plugin
- Designed for programmers who like to practice coding questions from online sources with test cases
- To add print functions to lines, it is easy for languages like Ruby that don't require parentheses around existing code. 
  - Adding the print function like `puts` in a block of test cases with multiple cursors or Visual block mode in Vim
- But it is cumbersome for languages that both use parentheses for function calls and `;` to indicate end of line
  - JavaScript needs a long `console.log(` followed by `);`
- Vim can make life lazier

---
## Features
- Provides the `cp` motion to toggle print functions on and off
- Toggles code lines with print functions like:
  - `console.log()` in JavaScript
  - `puts`, `p`, `print` in Ruby
  - `print()` in Python
  - ...etc
- Ignores empty lines and comment lines. 
  - If your test cases are at the bottom of the page, you can simply do `cpG` on the first line of test cases.
  - Or if you just want to add print to a paragraph that has both comment lines and test cases, you can do `cpip`
- Auto add comment characters after valid code in a given line (see more details below)
- Allows user to select which print functions to use if multiple options are available
- Works in both Vim Normal and Visual modes
- Allows the user to add print functions to languages not supported in the plugin

---
## Usage
- If using `vim-plug`, drop this in your plugin manager

  ```vim
  Plug 'steven-liou/console-puts'  " Toggle print functions on and off 
  ```
- The plugin comes with the Vim motion `cp`. It works in both Normal and Visual modes.
- It only allows the user to add number before the `cp` motion.
  - The available print options shown on screen after typing `cp` is only for user information.
- Examples :
  - To toggle the current line, `cpl` or `cpil`
  - To toggle two lines, `cpj`
  - To use a specific print function in line, like in Ruby using `print` instead of `puts`, `3cpl`
- The default behavior is to toggle print function on or off, so if your selection has lines that have print function and lines don't, they will flip.
  - In Ruby

      ```vim
      puts "this is line 1"
      "this is line 2"
      ```
  - If you enter `cpip`, the behavior is toggling   

      ```vim
      "this is line 1"
      puts "this is line 2"
      ```

- But if you input a number before `cp`, then it will apply the option to all lines
  - In Ruby, 

      ```vim
      puts "this is line 1"
      "this is line 2"
      ```

    - if you type `3cpip`, it will become

      ```vim
      print "this is line 1"
      print "this is line 2"
      ```

    - If you type a number that removes the print function, or any number not in the list, It will remove all print functions. Typing `4cpip` or `8cpip` from above example will get

      ```vim
      "this is line 1"
      "this is line 2"
      ```
- You can use the motion the same way in Visual mode

---
## Custom user mapping
- The users can remap the key by setting `let g:console_puts_mapping = 0`, in their `.vimrc` file. Then manually set custom mappings (default mapping is shown below)

  ```vim
  let g:console_puts_mapping = 0
  let g:console_puts_motion = 'cp'

  " if you want to map with a leader key
  let g:console_puts_mapping = 0
  let g:console_puts_motion = '<leader>p'
  ```
---
## Supported Programming Languages
- JavaScript
- Python
- Ruby
- Vim

---
### More details on plugin behaviors
- The plugin parses the "none-code" portion by first identifying an end of line character, either a `;` or a whitespace, then check if it is followed by one of:
  - an "invalid" characters like `->`, `>>` that typically come with online problems
  - another white space
  - comment character of the current language in the file
- If a line has an invalid character before comment character, it will move the comment character before invalid character.


---
### Todos
- More language support?
- Allow user to customize custom language print functions
- Allow user to customize invalid characters

