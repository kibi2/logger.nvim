#!/bin/sh
set -eu

case "${1:-run}" in
  pre)
    ;;
  post)
    LC_ALL=C sed \
    -e 's/\[[^]]*ms\]/[ms]/g' \
    -e 's/\[[^]]*MB\]/[MB]/g' \
    out-actual.txt > gen.txt
    mv gen.txt out-actual.txt
    ;;
esac
