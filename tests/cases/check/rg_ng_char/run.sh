#!/bin/sh
set -eu

echo $KIBI2_REPO_ROOT
LC_ALL=C rg --sort=path -g '*.lua' -g '*.sh' -g '*.vim' '[^\x00-\x7F]' $KIBI2_REPO_ROOT > out-actual.txt # no ascii

LC_ALL=C rg --sort=path "\bM:[a-zA-Z_]" $KIBI2_REPO_ROOT/lua | grep -v function >> out-actual.txt # no colon