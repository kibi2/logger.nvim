source $KIBI2_REPO_ROOT/tests/common.vim

CASE log ERROR

lua require("run1")

call Snapshot({'desc': 'ERROR1' })

CASE log trace

lua require("run2")

call Snapshot({'desc': 'ERROR2' })