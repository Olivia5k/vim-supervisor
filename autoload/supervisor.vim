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

" }}}
" Interface {{{1

function! s:Edit(cmd)
  exe a:cmd s:relpath(b:supervisor.config_file)
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

" }}}
" Initialization {{{1

function! s:BufCommands()
  com! -buffer Sedit    :call s:Edit('edit')
  com! -buffer Ssplit   :call s:Edit('split')
  com! -buffer Svsplit  :call s:Edit('vsplit')
  com! -buffer Stabedit :call s:Edit('tabedit')
endfunction

function! supervisor#BufInit()
  let sup = {}
  let sup.root = b:supervisor_root
  let sup.path = function('s:sup_path')
  let sup.config_file = sup.path('supervisord.conf')

  let b:supervisor = sup

  call s:BufCommands()
endfunction

" }}}

let &cpo = s:cpo_save
" vim:set sw=2 sts=2:
