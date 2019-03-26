#!/usr/bin/env bash

exe=.build/x86_64-unknown-linux/debug/flintc

SUCCESS=0
FAILURES=0
FAILED=""

for flintFile in `find . -not -path '*/\.*' -not -path './examples/future*' -not -path './examples/invalid*' -path './examples/*' -name *.flint`; do
  $exe -g $flintFile >&2
  if [ $? -eq 0 ]
  then
    SUCCESS=$(expr $SUCCESS + 1)
  else
    FAILURES=$(expr $FAILURES + 1)

    FAILED="$FAILED\n$flintFile"
  fi
done;

TOTAL=$(expr $SUCCESS + $FAILURES)

echo -e "\nFailed:$FAILED"
echo "Totals: $TOTAL - Pass: $SUCCESS, Failed: $FAILURES"
