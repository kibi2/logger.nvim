source $KIBI2_REPO_ROOT/tests/common.vim

lua require("run")

call Snapshot({ 'desc': 'line' })