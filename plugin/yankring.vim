" yankring.vim - Yank / Delete Ring for Vim
" ---------------------------------------------------------------
" Version:  1.5
" Authors:  David Fishburn <fishburn@ianywhere.com>
" Last Modified: Tue Mar 29 2005 3:06:25 PM
" Script:   http://www.vim.org/scripts/script.php?script_id=1234
" Based On: Mocked up version by Yegappan Lakshmanan
"           http://groups.yahoo.com/group/vim/post?act=reply&messageNum=34406
"  License: GPL (Gnu Public License)
" GetLatestVimScripts: 1234 1 :AutoInstall: yankring.vim

if exists('loaded_yankring') || &cp
    finish
endif

if v:version < 602
  echomsg 'yankring: You need at least Vim 6.2'
  finish
endif

let loaded_yankring = 15

" Allow the user to override the # of yanks/deletes recorded
if !exists('g:yankring_max_history')
    let g:yankring_max_history = 30
elseif g:yankring_max_history < 0
    let g:yankring_max_history = 30
endif

" Allow the user to specify if the plugin is enabled or not
if !exists('g:yankring_enabled')
    let g:yankring_enabled = 1
endif

" Specify a separation character for the key maps
if !exists('g:yankring_separator')
    let g:yankring_separator = ','
endif

" Specify max display length for each element for YRShow
if !exists('g:yankring_max_display')
    let g:yankring_max_display = 0
endif

" Controls whether the . operator will repeat yank operations
" The default is based on cpoptions: |cpo-y|
"	y	A yank command can be redone with ".".
if !exists('g:yankring_dot_repeat_yank')
    let g:yankring_dot_repeat_yank = (&cpoptions=~'y'?1:0)
endif

" Only adds unique items to the yankring.
" If the item already exists, that element is set as the
" top of the yankring.
if !exists('g:yankring_ignore_duplicate')
    let g:yankring_ignore_duplicate = 1
endif

" Allow the user to specify what characters to use for the mappings.
if !exists('g:yankring_n_keys')
    let g:yankring_n_keys = 'yy,dd,yw,dw,ye,de,yE,dE,yiw,diw,yaw,daw,y$,d$,Y,D,yG,dG,ygg,dgg'
endif

" Whether we sould map the . operator
if !exists('g:yankring_map_dot')
    let g:yankring_map_dot = 1
endif

if !exists('g:yankring_v_key')
    let g:yankring_v_key = 'y'
endif

if !exists('g:yankring_del_v_key')
    let g:yankring_del_v_key = 'd'
endif

if !exists('g:yankring_paste_n_bkey')
    let g:yankring_paste_n_bkey = 'P'
endif

if !exists('g:yankring_paste_n_akey')
    let g:yankring_paste_n_akey = 'p'
endif

if !exists('g:yankring_paste_v_bkey')
    let g:yankring_paste_v_bkey = 'P'
endif

if !exists('g:yankring_paste_v_akey')
    let g:yankring_paste_v_akey = 'p'
endif

if !exists('g:yankring_replace_n_pkey')
    let g:yankring_replace_n_pkey = '<C-P>'
endif

if !exists('g:yankring_replace_n_nkey')
    let g:yankring_replace_n_nkey = '<C-N>'
endif


" Enables or disables the yankring 
function! s:YRToggle(...)
    " Default the current state to toggle
    let new_state = ((g:yankring_enabled == 1) ? 0 : 1)

    " Allow the user to specify if enabled
    if a:0 > 0
        let new_state = ((a:1 == 1) ? 1 : 0)
    endif
            
    " YRToggle accepts an integer value to specify the state
    if new_state == g:yankring_enabled 
        return
    elseif new_state == 1
        call YRMapsCreate()
    else
        call YRMapsDelete()
    endif
endfunction
 

" Enables or disables the yankring 
function! s:YRShow(...) 
    if s:yr_count == 0
        echomsg 'YR: yankring is empty'
    else
        " If the user provided a range, exit after that many
        " have been displayed
        let iter = 0
        if a:0 > 0
            " If no yank command has been supplied, assume it is
            " a full line yank
            let iter = matchstr(a:1, '\d\+')
        endif
        if iter < 1 || iter > s:yr_count
            " The default range is the entire file
            let iter = s:yr_count
        endif

        let max_display = ((g:yankring_max_display == 0)?
                    \ (&columns - 10):
                    \ (g:yankring_max_display))

        " List is shown in order of replacement
        " assuming using previous yanks
        echomsg "--- YankRing ---"
        echomsg "Elem  Content"
        let elem = s:yr_paste_idx
        " let iter = s:yr_count
        while iter > 0
            let length = strlen(s:yr_elem_{elem})
            " Fancy trick to align them all regardless of how many
            " digits the element # is
            echomsg elem.strpart("      ",0,(6-strlen(elem))).
                        \ (
                        \ (length>max_display)?
                        \ (strpart(s:yr_elem_{elem},0,max_display).
                        \ '...'):
                        \ (s:yr_elem_{elem})
                        \ )
            let iter = iter - 1
            let elem = s:YRGetNextElem(elem, -1)
        endwhile
    endif
endfunction
 

" Paste a certain item from the yankring
" If no parameter is provided, this function becomes interactive.  It will
" display the list (using YRShow) and allow the user to choose an element.
function! s:YRGetElem(...) 
    if s:yr_count == 0
        echomsg 'YR: yankring is empty'
        return -1
    endif

    let default_buffer = ((&clipboard=='unnamed')?'*':'"')

    " Check to see if a specific value has been provided
    let elem = 0
    if a:0 > 0
        " Ensure we get only the numeric value (trim it)
        let elem = matchstr(a:1, '\d\+')
    else
        " If no parameter was supplied display the yankring
        " and prompt the user to enter the value they want pasted.
        YRShow
        let elem = input("Enter # to paste:")

        " Ensure we get only the numeric value (trim it)
        let elem = matchstr(elem, '\d\+')

        if elem == ''
            " They most likely pressed enter without entering a value
            return
        endif
    endif

    if elem < 1 || elem > s:yr_count
        echomsg "YR: Invalid choice:".elem
        return -1
    endif

    if !exists('s:yr_elem_'.elem)
        echomsg "YR: Elem:".elem." does not exist"
        return -1
    endif

    let default_buffer = ((&clipboard=='unnamed')?'*':'"')
    " let save_reg = getreg(default_buffer)
    " let save_reg_type = getregtype(default_buffer)
    call setreg(default_buffer
                \ , s:yr_elem_{elem}
                \ , s:yr_elem_type_{elem})
    exec "normal! p"
    " call setreg(default_buffer, save_reg, save_reg_type)

    " Set the previous action as a paste in case the user
    " press . to repeat
    call s:YRSetPrevOP('p', '', default_buffer)

endfunction
 

" Starting the the top of the ring it will paste x items from it
function! s:YRGetMultiple(reverse_order, ...) 
    if s:yr_count == 0
        echomsg 'YR: yankring is empty'
    else
        " If the user provided a range, exit after that many
        " have been displayed
        let iter = 0
        let elem = 0
        if a:0 > 0
            " If no yank command has been supplied, assume it is
            " a full line yank
            let iter = matchstr(a:1, '\d\+')
        endif
        if a:0 > 1
            " If no yank command has been supplied, assume it is
            " a full line yank
            let elem = matchstr(a:2, '\d\+')
        endif
        if iter < 1 
            " The default to only 1 item if no arguement is specified
            let iter = 1
        endif
        if iter > s:yr_count
            " Default to all items if they specified a very high value
            let iter = s:yr_count
        endif
        if elem < 1 || elem > s:yr_count
            " The default to only 1 item if no arguement is specified
            let elem = s:yr_paste_idx
        endif

        " Base the increment on the sort order of the results
        let increment = ((a:reverse_order==0)?(-1):(1))

        if a:reverse_order != 0
            " If there are 5 elements in the ring
            " User wants the top 3 in reverse order
            " We need to set the starting element to 3, because 3,4,5
            " Starting at the current element 5, we need to:
            " 1 + (3 * -1 * 1)
            " 1 + (-3)
            " -2
            " So start 2 elements below the current position
            let elem = s:YRGetNextElem(elem, (1+iter*-1*increment))
        endif

        while iter > 0
            " Paste the first item, and move on to the next.
            " digits the element # is
            call s:YRGetElem(elem)
            let elem = s:YRGetNextElem(elem, increment)
            let iter = iter - 1
        endwhile
    endif
endfunction
 

" Allows the user to specify what the next paste item should be.
" This is useful in conjunction with YRGetMultiple.
function! s:YRSetTop(set_top)
    if s:yr_count == 0
        echomsg 'YR: yankring is empty'
    else
        " If no yank command has been supplied, assume it is
        " a full line yank
        let elem = matchstr(a:set_top, '\d\+')
        if elem > 0 && elem <= s:yr_count
            " Valid choice, set the next paste index
            let s:yr_paste_idx = elem
            return elem
        else
            return -1
        endif
endfunction
 

" Clears the yankring by simply setting the # of items in it to 0.
" There is no need physically unlet each variable.
function! s:YRClear()
    let s:yr_next_idx  = 1
    let s:yr_paste_idx = 1
    let s:yr_count     = 0
    let s:yr_paste_dir = 'p'

    " For the . op support
    let s:yr_prev_op_code     = ''
    let s:yr_prev_count       = ''
    let s:yr_prev_reg         = ''
    let s:yr_prev_reg_unnamed = ''
    let s:yr_prev_reg_small   = ''
    let s:yr_prev_reg_insert  = ''
    let s:yr_prev_vis_lstart  = 0
    let s:yr_prev_vis_lend    = 0
    let s:yr_prev_vis_cstart  = 0
    let s:yr_prev_vis_cend    = 0

    " This is used to determine if the visual selection should be
    " reset prior to issuing the YRReplace
    let s:yr_prev_vis_mode    = 0
endfunction
 

" Determine which register the user wants to use
" For example the 'a' register:  "ayy
function! s:YRRegister()
    let user_register = v:register
    if &clipboard == 'unnamed' && user_register == '"'
        let user_register = '*'
    endif
    return user_register
endfunction


" Allows you to push a new item on the yankring.  Useful if something
" is in the clipboard and you want to add it to the yankring.
" Or if you yank something that is not mapped.
function! s:YRPush(...) 
    let user_register = s:YRRegister()

    if a:0 > 0
        " If no yank command has been supplied, assume it is
        " a full line yank
        let user_register = ((a:1 == '') ? user_register : a:1)
    endif

    " If we are pushing something on to the yankring, add it to
    " the default buffer as well so the next item pasted will
    " be the item pushed
    let default_buffer = ((&clipboard=='unnamed')?'*':'"')
    call setreg(default_buffer, getreg(user_register), 
                \ getregtype(user_register))

    call s:YRSetPrevOP('', '', '')
    call s:YRRecord(user_register)
endfunction


" Allows you to pop off the top elements from the yankring.
" You cannot remove elements from within the ring, only the
" highest elements.
function! s:YRPop(...) 
    if s:yr_count == 0
        echomsg 'YR: yankring is empty'
    else
        " If the user provided a range, exit after that many
        " have been displayed
        let iter = 0
        if a:0 > 0
            " If no yank command has been supplied, assume it is
            " a full line yank
            let iter = matchstr(a:1, '\d\+')
        endif
        if iter < 1 
            " The default is the most current element in the yankring
            let iter = 1
        endif
        if iter > s:yr_count
            " The default is the most current element in the yankring
            let iter = s:yr_count
        endif

        let default_buffer = ((&clipboard=='unnamed')?'*':'"')
        let elem = s:yr_next_idx - 1

        if elem == 0
            " It is a yankring, so reset it to the top
            let elem = s:yr_count
        endif

        while iter > 0
            " Safety check
            if exists('s:yr_elem_'.elem)
                unlet s:yr_elem_{elem}
                unlet s:yr_elem_type_{elem}
            endif
            " Reset the next items
            let s:yr_next_idx  = elem
            let s:yr_paste_idx = elem - 1
            let s:yr_count     = elem - 1
            let elem           = elem - 1
            let iter           = iter - 1
            if s:yr_count > 0 
                " Set the default buffer to the next entry
                " in the yankring
                call setreg(default_buffer
                            \ , s:yr_elem_{s:yr_paste_idx}
                            \ , s:yr_elem_type_{s:yr_paste_idx})
            endif
        endwhile
    endif
endfunction


" Adds this value to the yankring.
function! s:YRRecord(value) 

    if g:yankring_ignore_duplicate == 1
        " Ensure the element is not already in the yankring
        let iter = s:yr_count

        let elem = s:yr_paste_idx
        " let iter = s:yr_count
        while iter > 0
            if getreg(a:value) == s:yr_elem_{elem}
                exec "YRSetTop ".elem
                " echomsg "YR: Same as element: ".elem
                return
            endif
            let iter = iter - 1
            let elem = s:YRGetNextElem(elem, -1)
        endwhile
    endif

    let s:yr_elem_{s:yr_next_idx}      = getreg(a:value)
    let s:yr_elem_type_{s:yr_next_idx} = getregtype(a:value)
    let s:yr_paste_idx                 = s:yr_next_idx

    if s:yr_count < g:yankring_max_history
        let s:yr_count = s:yr_count + 1
    endif

    let s:yr_next_idx = s:yr_next_idx + 1
    if s:yr_next_idx > g:yankring_max_history
        let s:yr_next_idx = 1
    endif

endfunction


" Record the operation for the dot operator
function! s:YRSetPrevOP(op_code, count, reg) 
    let s:yr_prev_op_code     = a:op_code
    let s:yr_prev_count       = a:count
    let s:yr_prev_reg         = a:reg
    let s:yr_prev_reg_unnamed = getreg('"')
    let s:yr_prev_reg_small   = getreg('-')
    let s:yr_prev_reg_insert  = getreg('.')
    let s:yr_prev_vis_lstart  = line("'<")
    let s:yr_prev_vis_lend    = line("'>")
    let s:yr_prev_vis_cstart  = col("'<")
    let s:yr_prev_vis_cend    = col("'>")
    let s:yr_prev_chg_lstart  = line("'[")
    let s:yr_prev_chg_lend    = line("']")
    let s:yr_prev_chg_cstart  = col("'[")
    let s:yr_prev_chg_cend    = col("']")

    " If storing the last change position (using '[, '])
    " is not good enough, then another option is to:
    " Use :redir on the :changes command
    " and grab the last item.  Store this value
    " and compare it is YRDoRepeat.
    "
endfunction


" Adds this value to the yankring.
function! s:YRDoRepeat() 
    let dorepeat = 0

    " Check the previously recorded value of the registers
    " if they are the same, we need to reissue the previous
    " yankring command.
    " If any are different, the user performed a command
    " command that did not involve the yankring, therefore
    " we should just issue the standard "normal! ." to repeat it.
    if s:yr_prev_reg_unnamed == getreg('"') &&
                \ s:yr_prev_reg_small  == getreg('-') &&
                \ s:yr_prev_reg_insert == getreg('.') &&
                \ s:yr_prev_vis_lstart == line("'<") &&
                \ s:yr_prev_vis_lend   == line("'>") &&
                \ s:yr_prev_vis_cstart == col("'<") &&
                \ s:yr_prev_vis_cend   == col("'>") &&
                \ s:yr_prev_chg_lstart == line("'[") &&
                \ s:yr_prev_chg_lend   == line("']") &&
                \ s:yr_prev_chg_cstart == col("'[") &&
                \ s:yr_prev_chg_cend   == col("']") 
        let dorepeat = 1
    endif
    " If we are going to repeat check to see if the
    " previous command was a yank operation.  If so determine
    " if yank operations are allowed to be repeated.
    if dorepeat == 1 && s:yr_prev_op_code =~ '^y'
        " This value be default is set based on cpoptions.
        if g:yankring_dot_repeat_yank == 0
            let dorepeat = 0
        endif
    endif
    return dorepeat
endfunction


" This internal function will add and subtract values from a starting
" point and return the correct element number.  It takes into account
" the circular nature of the yankring.
function! s:YRGetNextElem(start, iter) 
    let elem      = a:start
    let iter      = a:iter
    let increment = ((iter>0)?1:-1)
    
    while iter != 0
        " Get the next item from the yankring
        let elem = elem + increment
        if elem == 0 
            if s:yr_count == g:yankring_max_history
                let elem = g:yankring_max_history
            else
                let elem = s:yr_next_idx + increment
            endif
        elseif elem > s:yr_count
            let elem = 1
        endif

        let iter = iter + ((iter > 0)?-1:1)
    endwhile

    return elem
endfunction


" Lets Vim natively perform the operation and then stores what
" was yanked (or deleted) into the yankring.
" Supports this for example -   5"ayy
function! s:YRYankCount(...) range

    let user_register = s:YRRegister()
    let v_count = v:count

    " Default yank command to the entire line
    let op_code = 'yy'
    if a:0 > 0
        " If no yank command has been supplied, assume it is
        " a full line yank
        let op_code = ((a:1 == '') ? op_code : a:1)
    endif

    if op_code == '.'
        if s:YRDoRepeat() == 1
            if s:yr_prev_op_code != ''
                let op_code       = s:yr_prev_op_code
                let v_count       = s:yr_prev_count
                let user_register = s:yr_prev_reg
            endif
        else
            exec "normal! ."
            return
        endif
    endif

    " Supports this for example -   5"ayy
    " A delete operation will still place the items in the
    " default registers as well as the named register
    exec "normal! ".
                \ ((v_count > 0)?(v_count):'').
                \ (user_register=='"'?'':'"'.user_register).
                \ op_code

    if user_register == '_'
        " Black hole register, ignore
        return
    endif
    
    call s:YRSetPrevOP(op_code, v_count, user_register)

    call s:YRRecord(user_register)
endfunction
 

" Handles ranges.  There are visual ranges and command line ranges.
" Visual ranges are easy, since we passthrough and let Vim deal
" with those directly.
" Command line ranges means we must yank the entire line, and not
" just a portion of it.
function! s:YRYankRange(do_delete_selection, ...) range

    let user_register  = s:YRRegister()
    let default_buffer = ((&clipboard=='unnamed')?'*':'"')

    " Default command mode to normal mode 'n'
    let cmd_mode = 'n'
    if a:0 > 0
        " Change to visual mode, if command executed via
        " a visual map
        let cmd_mode = ((a:1 == 'v') ? 'v' : 'n')
    endif

    if cmd_mode == 'v' 
        " We are yanking either an entire line, or a range 
        exec "normal! gv".
                    \ (user_register==default_buffer?'':'"'.user_register).
                    \ 'y'
        if a:do_delete_selection == 1
            exec "normal! gv".
                        \ (user_register==default_buffer?'':'"'.user_register).
                        \ 'd'
        endif
    else
        " In normal mode, always yank the complete line, since this
        " command is for a range.  YRYankCount is used for parts
        " of a single line
        if a:do_delete_selection == 1
            exec a:firstline . ',' . a:lastline . 'delete '.user_register
        else
            exec a:firstline . ',' . a:lastline . 'yank ' . user_register
        endif
    endif

    if user_register == '_'
        " Black hole register, ignore
        return
    endif
    
    call s:YRSetPrevOP('', '', user_register)
    call s:YRRecord(user_register)
endfunction
 

" Paste from either the yankring or from a specified register
" Optionally a count can be provided, so paste the same value 10 times 
function! s:YRPaste(replace_last_paste_selection, nextvalue, direction, ...) 
    " Disabling the yankring removes the default maps.
    " But there are some maps the user can create on their own, and 
    " these would most likely call this function.  So place an extra
    " check and display a message.
    if g:yankring_enabled == 0
        echomsg 'YR: The yankring is currently disabled, use YRToggle.'
        return
    endif
    
    let user_register  = s:YRRegister()
    let default_buffer = ((&clipboard=='unnamed')?'*':'"')
    let v_count = v:count

    " Default command mode to normal mode 'n'
    let cmd_mode = 'n'
    if a:0 > 0
        " Change to visual mode, if command executed via
        " a visual map
        let cmd_mode = ((a:1 == 'v') ? 'v' : 'n')
    endif

    " User has decided to bypass the yankring and specify a specific 
    " register
    if user_register != default_buffer
        if a:replace_last_paste_selection == 1
            echomsg 'YR: A register cannot be specified in replace mode'
            return
        else
            exec "normal! ".
                        \ ((cmd_mode=='n') ? "" : "gv").
                        \ ((v_count > 0)?(v_count):'').
                        \ (user_register==default_buffer?'':'"'.user_register).
                        \ (a:direction =~ 'b'?'P':'p')
        endif
        let s:yr_paste_dir     = a:direction
        let s:yr_prev_vis_mode = ((cmd_mode=='n') ? 0 : 1)
        return
    endif

    " Try to second guess the user to make these mappings less intrusive.
    " If the user hits paste compare the contents of the paste register
    " to the current entry in the yankring.  If they are different, lets
    " assume the user wants the contents of the paste register.
    " So if they pressed [yt ] (yank to space) and hit paste, the yankring
    " would not have the word in it, so assume they want the word pasted.
    if a:replace_last_paste_selection != 1 
        if s:yr_count > 0
            if getreg(default_buffer) != s:yr_elem_{s:yr_paste_idx}
                exec "normal! ".
                            \ ((cmd_mode=='n') ? "" : "gv").
                            \ ((v_count > 0)?(v_count):'').
                            \ (a:direction =~ 'b'?'P':'p')
                let s:yr_paste_dir     = a:direction
                let s:yr_prev_vis_mode = ((cmd_mode=='n') ? 0 : 1)
                return
            endif
        else
            exec "normal! ".
                        \ ((cmd_mode=='n') ? "" : "gv").
                        \ ((v_count > 0)?(v_count):'').
                        \ (a:direction =~ 'b'?'P':'p')
            let s:yr_paste_dir     = a:direction
            let s:yr_prev_vis_mode = ((cmd_mode=='n') ? 0 : 1)
            return
        endif
    endif

    if s:yr_count == 0
        echomsg 'YR: yankring is empty'
        " Nothing to paste
        return
    endif

    if a:replace_last_paste_selection == 1
        " Replacing the previous put
        let start = line("'[")
        let end = line("']")

        if start != line('.')
            echomsg 'YR: You must paste text first, before you can replace'
            return
        endif

        if start == 0 || end == 0
            return
        endif

        " If a count was provided (ie 5<C-P>), multiply the 
        " nextvalue accordingly and position the next paste index
        let value = a:nextvalue * ((v_count > 0)?(v_count):1)
        let s:yr_paste_idx = s:YRGetNextElem(s:yr_paste_idx, value)

        let save_reg = getreg(default_buffer)
        let save_reg_type = getregtype(default_buffer)
        call setreg(default_buffer
                    \ , s:yr_elem_{s:yr_paste_idx}
                    \ , s:yr_elem_type_{s:yr_paste_idx})

        " First undo the previous paste
        exec "normal! u"
        " Check if the visual selection should be reselected
        " Next paste the correct item from the ring
        " This is done as separate statements since it appeared that if 
        " there was nothing to undo, the paste never happened.
        exec "normal! ".
                    \ ((s:yr_prev_vis_mode==0) ? "" : "gv").
                    \ ((s:yr_paste_dir =~ 'b')?'P':'p')
        call setreg(default_buffer, save_reg, save_reg_type)
        call s:YRSetPrevOP('', '', '')
    else
        " User hit p or P
        " Supports this for example -   5"ayy
        " And restores the current register
        let save_reg = getreg(default_buffer)
        let save_reg_type = getregtype(default_buffer)
        call setreg(default_buffer
                    \ , s:yr_elem_{s:yr_paste_idx}
                    \ , s:yr_elem_type_{s:yr_paste_idx})
        exec "normal! ".
                    \ ((cmd_mode=='n') ? "" : "gv").
                    \ (
                    \ ((v_count > 0)?(v_count):'').
                    \ ((a:direction =~ 'b')?'P':'p')
                    \ )
        call setreg(default_buffer, save_reg, save_reg_type)
        call s:YRSetPrevOP(
                    \ ((a:direction =~ 'b')?'P':'p')
                    \ , v_count
                    \ , default_buffer)
        let s:yr_paste_dir     = a:direction
        let s:yr_prev_vis_mode = ((cmd_mode=='n') ? 0 : 1)
    endif

endfunction
 

" Create the default maps
function! YRMapsCreate()

    " Iterate through a comma separated list of mappings and create
    " calls to the YRYankCount function
    if g:yankring_n_keys != ''
        let index = 0
        while index > -1
            " Retrieve the keystrokes for the mappings
            let sep_end = match(g:yankring_n_keys, g:yankring_separator, index)
            if sep_end > 0
                let cmd = strpart(g:yankring_n_keys, index, (sep_end - index))
            else
                let cmd = strpart(g:yankring_n_keys, index)
            endif
            " Creating the mapping and pass the key strokes into the
            " YRYankCount function so it knows how to replay the same
            " command
            if strlen(cmd) > 0
                exec 'nnoremap <silent>'.cmd." :<C-U>YRYankCount '".cmd."'<CR>"
            endif
            " Move onto the next entry in the comma separated list
            let index = index + strlen(cmd) + strlen(g:yankring_separator)
            if index >= strlen(g:yankring_n_keys)
                break
            endif
        endwhile
    endif
    if g:yankring_map_dot == 1
        exec "nnoremap <silent> .  :<C-U>YRYankCount '.'<CR>"
    endif
    if g:yankring_v_key != ''
        exec 'vnoremap <silent>'.g:yankring_v_key." :YRYankRange 'v'<CR>"
    endif
    if g:yankring_del_v_key != ''
        exec 'vnoremap <silent>'.g:yankring_del_v_key." :YRDeleteRange 'v'<CR>"
    endif
    if g:yankring_paste_n_bkey != ''
        exec 'nnoremap <silent>'.g:yankring_paste_n_bkey." :<C-U>YRPaste 'b'<CR>"
    endif
    if g:yankring_paste_n_akey != ''
        exec 'nnoremap <silent>'.g:yankring_paste_n_akey." :<C-U>YRPaste 'a'<CR>"
    endif
    if g:yankring_paste_v_bkey != ''
        exec 'vnoremap <silent>'.g:yankring_paste_v_bkey." :<C-U>YRPaste 'b', 'v'<CR>"
    endif
    if g:yankring_paste_v_akey != ''
        exec 'vnoremap <silent>'.g:yankring_paste_v_akey." :<C-U>YRPaste 'a', 'v'<CR>"
    endif
    if g:yankring_replace_n_pkey != ''
        exec 'nnoremap <silent>'.g:yankring_replace_n_pkey." :<C-U>YRReplace '-1', 'b'<CR>"
    endif
    if g:yankring_replace_n_nkey != ''
        exec 'nnoremap <silent>'.g:yankring_replace_n_nkey." :<C-U>YRReplace '1', 'a'<CR>"
    endif

    let g:yankring_enabled = 1
endfunction
 

" Create the default maps
function! YRMapsDelete()

    " Iterate through a comma separated list of mappings and create
    " calls to the YRYankCount function
    if g:yankring_n_keys != ''
        let index = 0
        while index > -1
            " Retrieve the keystrokes for the mappings
            let sep_end = match(g:yankring_n_keys, g:yankring_separator, index)
            if sep_end > 0
                let cmd = strpart(g:yankring_n_keys, index, (sep_end - index))
            else
                let cmd = strpart(g:yankring_n_keys, index)
            endif
            " Creating the mapping and pass the key strokes into the
            " YRYankCount function so it knows how to replay the same
            " command
            if strlen(cmd) > 0
                exec 'nunmap '.cmd
            endif
            " Move onto the next entry in the comma separated list
            let index = index + strlen(cmd) + strlen(g:yankring_separator)
            if index >= strlen(g:yankring_n_keys)
                break
            endif
        endwhile
    endif
    if g:yankring_map_dot == 1
        exec "nunmap ."
    endif
    if g:yankring_v_key != ''
        exec 'vunmap '.g:yankring_v_key
    endif
    if g:yankring_del_v_key != ''
        exec 'vunmap '.g:yankring_del_v_key
    endif
    if g:yankring_paste_n_bkey != ''
        exec 'nunmap '.g:yankring_paste_n_bkey
    endif
    if g:yankring_paste_n_akey != ''
        exec 'nunmap '.g:yankring_paste_n_akey
    endif
    if g:yankring_paste_v_bkey != ''
        exec 'vunmap '.g:yankring_paste_v_bkey
    endif
    if g:yankring_paste_v_akey != ''
        exec 'vunmap '.g:yankring_paste_v_akey
    endif
    if g:yankring_replace_n_pkey != ''
        exec 'nunmap '.g:yankring_replace_n_pkey
    endif
    if g:yankring_replace_n_nkey != ''
        exec 'nunmap '.g:yankring_replace_n_nkey
    endif

    let g:yankring_enabled = 0
endfunction


" Public commands
command! -count -register -nargs=* YRYankCount   call s:YRYankCount(<args>)
command! -range -bang     -nargs=? YRYankRange   <line1>,<line2>call s:YRYankRange(<bang>0, <args>)
command! -range -bang     -nargs=? YRDeleteRange <line1>,<line2>call s:YRYankRange(<bang>1, <args>)
command! -count -register -nargs=* YRPaste       call s:YRPaste(0,1,<args>)
command! -count -register -nargs=* YRReplace     call s:YRPaste(1,<args>)
command!        -register -nargs=? YRPush        call s:YRPush(<args>)
command!                  -nargs=? YRPop         call s:YRPop(<args>)
command!                  -nargs=? YRToggle      call s:YRToggle(<args>)
command!                  -nargs=? YRShow        call s:YRShow(<args>)
command!                           YRClear       call s:YRClear()
command!                  -nargs=? YRGetElem     call s:YRGetElem(<args>)
command!        -bang     -nargs=? YRGetMultiple call s:YRGetMultiple(<bang>0, <args>)
command!                  -nargs=1 YRSetTop      call s:YRSetTop(<args>)

" Initialize YankRing
call s:YRClear()

if g:yankring_enabled == 1
    " Create YankRing Maps
    call YRMapsCreate()
endif

if exists('*YRRunAfterMaps') 
    call YRRunAfterMaps()
endif

