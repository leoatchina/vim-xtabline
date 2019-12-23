"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands and functions that handle the working directory
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:X    = g:xtabline
let s:v    = s:X.Vars
let s:Sets = g:xtabline_settings
let s:T    = { -> s:X.Tabs[tabpagenr()-1] } "current tab

let s:Dir  = {}

fun! xtabline#dir#init(funcs)
  let s:F = a:funcs
  return extend(a:funcs, s:Dir)
endfun "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" When we change directory, we can use either `cd`, `tcd` or `lcd`.
" The user issues a command, this is confronted with the current type of
" working directory.
"
" Mappings are:
"
"   CDW: prompts for a global directory, confirm if a :tcd or :lcd is found
"   CDC: automatic (cd directory of current file), confirm as above
"   CDD: automatic (cd N directories below current file), confirm as above
"   CDT: prompts for a tab-local directory, no confirmation
"   CDL: prompts for a window-local directory, no confirmation
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! xtabline#dir#cd(count) abort
  " Set cwd relatively to directory of current file.  {{{1

  let path = ':p:h'
  for c in range(max([a:count, 0]))
    let path .= ':h'
  endfor
  let dir = s:F.fulldir(expand("%"), path)
  if !empty(expand("%")) && empty(dir)
    let dir = '/'
  endif
  call s:F.manual_cwd(dir, 'working')
endfun "}}}


fun! xtabline#dir#set(...) abort
  " Set new working/local/tab directory. {{{1

  let [ type, bang, dir ] = [ a:1, a:2, a:3 ]

  if !bang && empty(dir)
    let base = s:F.fulldir(s:F.find_root_dir())
    let dir = s:F.input("Enter a new ".type." directory: ", base, "file")
  else
    let dir = s:F.fulldir(dir)
  endif

  if empty(dir)
    call s:F.msg ([[ "Canceled.", 'WarningMsg' ]])

  elseif s:F.manual_cwd(dir, type)
    " reset tab name if directory change was successful
    let s:X.Tabs[tabpagenr()-1].name = ''
  endif

  call xtabline#update()
endfun "}}}


fun! xtabline#dir#info() abort
  " Print current repo/cwd/tagfiles information. {{{1

  " show window cwd, if present
  if s:Dir.is_local_dir()
    echo printf("%-20s %s", 'Current local cwd:', getcwd(winnr(), tabpagenr()))
  endif

  " show tab cwd, if present
  if s:Dir.is_tab_dir()
    echo printf("%-20s %s", 'Current tab cwd:', getcwd(-1, 0))
  endif

  " show global cwd otherwise
  if !s:Dir.is_tab_dir() && !s:Dir.is_local_dir()
    echo printf("%-20s %s", 'Current cwd:', getcwd())
  endif

  " show git dir
  if exists('*FugitiveGitDir')
    let gitdir = substitute(FugitiveGitDir(), '/\.git$', '', '')
    let gitdir = has('win32') ? substitute(gitdir, '\\\ze[^ ]', '/', 'g') : gitdir
  else
    let gitdir = s:Dir.find_root_dir()
  endif
  if gitdir != ''
    echo printf("%-20s %s", 'Current git dir:', gitdir)
  endif

  " show current tagfiles
  if !empty(tagfiles())
    echo printf("%-20s %s", 'Tag files:', string(tagfiles()))
  endif
endfun "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Dir.manual_cwd(dir, type) abort
  " Set the working directory through mappings or Ex commands. {{{1
  " Confirmation may be needed.
  let dir = match(a:dir, '\%(/\|\\\)$') > 0 ? a:dir[:-2] : a:dir

  if !isdirectory(dir)
    return self.msg("Invalid directory: ".dir, 1)
  endif
  call extend(s:T(), { 'cwd': dir })

  let [error, out] = self.change_wd(dir, a:type)

  if error
    return self.msg([[ "Directory not set: ", 'WarningMsg' ], [ out, 'None' ]])
  endif

  call xtabline#update()
  call self.msg ([[ out." directory: ", 'Label' ], [ dir, 'None' ]])
  return 1
endfun "}}}


fun! s:Dir.change_wd(dir, type) abort
  " Change working directory, update tab cwd and session data. {{{1

  let [type, error, out] = [a:type, 0, a:type]

  if s:Dir.no_difference(type, a:dir)
      let [error, out] = [1, 'no difference']

  elseif type == 'window-local'
    " explicitly asking to set a window-local working directory
      exe 'lcd' a:dir

  elseif type == 'tab-local'
    " explicitly asking to set a tab-local working directory
      exe 'tcd' a:dir

  elseif self.is_local_dir() && getcwd() ==# a:dir
    " same directory as current window-local directory, either keep or clear {{{2
    let action = confirm('Same as current window-local directory, keep it or clear it?',
          \"&Keep\n&Clear")

    if action < 2
      let [error, out] = [1, 'window-local directory unchanged']
    else
      exe 'cd' a:dir
      let [error, out] = [0, 'working']
    endif "}}}

  elseif self.is_local_dir()
    " there is a window-local directory that would be overwritten, ask {{{2
    let action = confirm('Overwrite window-local directory ' .getcwd(). '?',
          \"&Yes\n&No\n&Clear")

    if action == 1
      exe 'lcd' a:dir
      let [error, out] = [0, 'window-local']
    elseif action == 3
      exe 'cd' a:dir
    else
      let [error, out] = [1, 'window-local directory unchanged']
    endif "}}}

  elseif self.is_tab_dir() && getcwd(-1, 0) ==# a:dir
    " same directory as current tab-local directory, either keep or clear {{{2
    let action = confirm('Same as current tab-local directory, keep it or clear it?',
          \"&Keep\n&Clear")

    if action < 2
      let [error, out] = [1, 'tab-local directory unchanged']
    else
      exe 'cd' a:dir
      let [error, out] = [0, 'working']
    endif "}}}

  elseif self.is_tab_dir()
    " there is a tab-local directory that would be overwritten, ask {{{2
    let action = confirm('Overwrite tab-local directory ' .getcwd(-1, 0). '?',
          \"&Yes\n&No\n&Clear")

    if action == 1
      exe 'tcd' a:dir
      let [error, out] = [0, 'tab-local']
    elseif action == 3
      exe 'cd' a:dir
    else
      let [error, out] = [1, 'tab-local directory unchanged']
    endif "}}}

  else
    " no tab cwd, no local cwd: just cd
    exe 'cd' a:dir
  endif

  call self.set_tab_wd()
  call xtabline#update_this_session()
  return [error, out]
endfun "}}}


fun! s:Dir.auto_change_dir(dir) abort
  " Not a manual cwd change, it will be applied if a local cwd is already set. "{{{1
  let T = s:T()

  if getcwd() ==# a:dir
    return
  endif

  if self.is_local_dir()
    exe 'lcd' a:dir
  elseif self.is_tab_dir()
    exe 'tcd' a:dir
  endif

  call self.set_tab_wd()
  call xtabline#update_this_session()
endfun "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


fun! s:Dir.set_tab_wd() abort
  " Update the tab object's working directory. {{{1
  let s:X.Tabs[tabpagenr()-1].cwd = self.fulldir(getcwd())
endfun "}}}


fun! s:Dir.find_root_dir(...) abort
  " Look for a VCS dir below current directory {{{1

  let current = a:0 ? a:1 : shellescape(expand("%:h"))
  let dir = system('git -C '.current.' rev-parse --show-toplevel')[:-2]
  return !empty(dir) && !v:shell_error ? dir
        \: a:0 ? a:1
        \: isdirectory(current) ? current : getcwd()
endfun "}}}


fun! s:Dir.is_local_dir() abort
  "Check if there is a window-local directory. {{{1
  return haslocaldir(winnr(), tabpagenr()) == 1
endfun "}}}


fun! s:Dir.is_tab_dir() abort
  "Check if there is a tab-local directory. {{{1
  return exists(':tcd') == 2 && haslocaldir(-1, 0)
endfun "}}}


fun s:Dir.no_difference(type, dir)
  " Check if the the requested directory and type match the current ones. {{{1
  let [window, tab] = [self.is_local_dir(), self.is_tab_dir()]

  return     (a:type == 'window-local'  && window  && getcwd(0, 0) ==# a:dir)
        \ || (a:type == 'tab-local'     && tab     && getcwd(-1, 0) ==# a:dir)
        \ || (a:type == 'working'       && !window && !tab && getcwd() ==# a:dir)
endfun "}}}


" vim: et sw=2 ts=2 sts=2 fdm=marker
