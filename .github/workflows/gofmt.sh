#!/bin/sh

if [ -z "$1" ]; then
    rm -f ./gofmterr
    find . -iname '*.go' ! -name '*.pb.go' -exec "$0" {} \;
    [ -f ./gofmterr ] && exit 1
    exit 0
fi

OUT="$(./nebula/goimports -d "$1" | awk '{printf "%s%%0A",$0}')"
if [ -n "$OUT" ]; then
    echo "::error file=$1::$OUT"
    touch ./gofmterr
fi