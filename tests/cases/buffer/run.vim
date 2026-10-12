source $KIBI2_REPO_ROOT/tests/common.vim

CASE log.xxx(...)
		lua require("run")

let bufnr = -1
for buf in getbufinfo()
  if buf.name =~# 'kibi2://log'
    let bufnr = buf.bufnr
    break
  endif
endfor

let lines = bufnr > 0 ? getbufline(bufnr, 1, '$') : []
for line in lines
  if line !~# '^\s*$'
    echomsg line
  endif
endfor

call Snapshot({})