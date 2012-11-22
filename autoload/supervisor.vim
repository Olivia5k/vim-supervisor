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

" }}}
" Interface {{{1

function! s:Edit(cmd)
  exe a:cmd s:relpath(b:supervisor.config_file)
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

function! s:parse_config() dict abort
  let config = {}
  let header = ''
  for line in readfile(self.config_file)
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

  let self.config = config
endfunction

function! s:write_index() dict abort
  silent exe '!supervisorctl -c' self.config_file 'status >' self.index
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
