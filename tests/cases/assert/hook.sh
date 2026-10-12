#!/bin/sh
set -eu

case "${1:-run}" in
  pre)
    ;;
  post)
    LC_ALL=C sed \
    -e 's/^Error .*$/Error .../' \
    -e 's/^E5108: .*$/E5108: .../' \
    -e '/.* in function /d' \
    out-actual.txt > gen.txt
    mv gen.txt out-actual.txt
    ;;
esac
