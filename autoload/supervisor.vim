" autoload/supervisor.vim
" Author:       Lowe Thiderman <lowe.thiderman@gmail.com>

" Install this file as autoload/supervisor.vim.

if exists('g:autoloaded_supervisor') || &cp
  finish
endif
let g:autoloaded_supervisor = '0.1'

let s:cpo_save = &cpo
set cpo&vim

" Utilities {{{1

function! s:relpath(path, ...)
  let path = fnamemodify(a:path, ':p')

  if a:0
    let rel = fnamemodify(a:1, ':p')
    return substitute(path, rel, '', '')
  else
    let rel = getcwd() . '/'
    let rel = substitute(path, rel, '', '')
    return rel == '' ? './' : rel
  endif
endfunction

function! s:strip(str)
  return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function s:current_app()
  let dir = fnamemodify(expand('%'), ':p:h')

  for [app, data] in items(b:supervisor.apps)
    if data.config.directory =~ '^' . dir
      return app
    endif
  endfor

  return ""
endfunction

" }}}
" Interface {{{1

function! s:Edit(cmd)
  exe a:cmd s:relpath(b:supervisor.config_file)
endfunction

function! s:Log(name, ...)
  let cmd = a:0 ? a:1 : 'edit'

  if &filetype == "supervisor"
    " We are in the supervisor status buffer.
    let app = s:status_app()
    wincmd p
  else
    " We are in any other buffer
    let app = s:current_app()
    if app == ""
      return s:Status('Could not determine app. Please browse manually.')
    endif
  endif

  exe cmd s:relpath(b:supervisor.apps[app][a:name]())
endfunction

function! supervisor#ctl()
  return b:supervisor
endfunction

" }}}
" Sstatus {{{1

function! s:Status()
  call b:supervisor.write_index()

  pedit `=b:supervisor.index`
  wincmd P
  setlocal ro bufhidden=wipe filetype=supervisor
  nnoremap <buffer> <silent> q :<C-U>bdelete<CR>
  redraw!
endfunction

" }}}
" Supervisor object methods {{{1

function! s:sup_path(...) dict abort
  let ret = [self.root]
  for str in a:000
    let ret = add(ret, substitute(str, '/\+$', '', ''))
  endfor
  return join(ret, '/')
endfunction

function! s:parse_config_file(file)
  let config = {}
  let header = ''

  for line in readfile(a:file)
    if line =~ '^\s*;' || line =~ '^\s*$'
      continue  " Empty lines or comments
    endif

    if line =~ '^['
      let m = matchlist(line, '\[\(.*\)\]')
      if len(m) != 0
        let header = m[1]
      endif
      continue
    endif

    let line = substitute(line, '\s*;.*$', '', '')
    if !has_key(config, header)
      let config[header] = {}
    endif
    let split = split(line, '=')
    let key = s:strip(split[0])
    let value = s:strip(split[1])

    let config[header][key] = value
  endfor

  return config
endfunction

function! s:parse_config() dict abort
  let config = s:parse_config_file(self.config_file)
  if has_key(config, 'include') && has_key(config['include'], 'files')
    for file in split(globpath(self.root, config['include']['files']), '\n')
      for [key, value] in items(s:parse_config_file(file))
        let config[key] = value
      endfor
    endfor
  endif

  let apps = {}
  for [key, value] in items(config)
    if key =~ '^program:'
      let name = split(key, ':')[1]
      let apps[name] = s:setup_app(name, value, self)
      unlet config[key]
    endif
  endfor

  let self.apps = apps
  let self.config = config
endfunction

function! s:setup_app(name, data, root)
  let app = {}
  let app.program_name = a:name
  let app.config = a:data
  let app.root = a:root

  let app.cmd = function('SupervisorAppCmd')
  let app.start = function('SupervisorAppStart')
  let app.stop = function('SupervisorAppStop')
  let app.restart = function('SupervisorAppRestart')
  let app.logfile = function('SupervisorAppLogfile')
  let app.stdout = function('SupervisorAppStdout')
  let app.stderr = function('SupervisorAppStderr')

  return app
endfunction

function! s:write_index() dict abort
  silent exe '!supervisorctl -c' self.config_file 'status >' self.index
endfunction

" }}}
" App object methods {{{1

function! SupervisorAppCmd(cmd) dict abort
  exe '!supervisorctl -c' self.root.config_file a:cmd self.program_name
endfunction

function! SupervisorAppLogfile(pipe) dict abort
  let logfile = self.config[a:pipe . '_logfile']

  if logfile =~ '%(program_name)s'
    let logfile = substitute(logfile, '%(program_name)s', self.program_name, 'g')
  endif
  return self.root.path(logfile)
endfunction

function! SupervisorAppStart() dict abort
  return self.cmd('start')
endfunction

function! SupervisorAppStop() dict abort
  return self.cmd('stop')
endfunction

function! SupervisorAppRestart() dict abort
  return self.cmd('restart')
endfunction

function! SupervisorAppStdout() dict abort
  return self.logfile('stdout')
endfunction

function! SupervisorAppStderr() dict abort
  return self.logfile('stderr')
endfunction

" }}}
" Initialization {{{1

function! s:BufCommands()
  com! -buffer Sedit    :call s:Edit('edit')
  com! -buffer Ssplit   :call s:Edit('split')
  com! -buffer Svsplit  :call s:Edit('vsplit')
  com! -buffer Stabedit :call s:Edit('tabedit')

  com! -buffer Sstatus :call s:Status()
endfunction

function! s:BufMappings()
  nmap <buffer> <silent> S :<C-U>Sstatus<cr>
endfunction

function! supervisor#BufInit()
  let sup = {}
  let sup.root = b:supervisor_root
  let sup.path = function('s:sup_path')
  let sup.config_file = sup.path('supervisord.conf')

  let sup.parse_config = function('s:parse_config')
  call sup.parse_config()

  " TODO: What if it does not have this config?
  let piddir = fnamemodify(sup.config['supervisord']['pidfile'], ':h')
  let sup.index = sup.path(piddir, 'index')
  let sup.write_index = function('s:write_index')

  let b:supervisor = sup

  call s:BufCommands()
  call s:BufMappings()
endfunction

" }}}

let &cpo = s:cpo_save
" vim:set sw=2 sts=2:
