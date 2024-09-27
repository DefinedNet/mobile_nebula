#!/bin/sh
DIRS="lib test"
EXIT=0

for DIR in $DIRS; do
    OUT="$(dart format -l 120 --suppress-analytics "$DIR" | sed -e "s/^Formatted \(.*\)/::error file=$DIR\/\1::Not formatted/g")"
    echo "$OUT" | grep "::error" && EXIT=1
done

exit $EXIT