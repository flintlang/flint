#! /bin/bash

ERRORS=0

swift test &> /dev/null
if [ $? -ne 0 ]; then
  ERRORS=$(($ERRORS + 1))
fi

for dir in valid warnings
do
  for f in examples/$dir/*.ethl 
  do
    .build/x86_64-apple-macosx10.10/debug/etherlang $f --emit-ir &> /dev/null
    if [ $? -ne 0 ]; then
      ERRORS=$(($ERRORS + 1))
      echo "Compilation failed: $f"
    fi

    solFile=${f%.*}.sol
    solc $solFile &> /dev/null
    if [ $? -ne 0 ]; then
      echo "Solc failed: $solFile"
    fi
  done

  for f in examples/warnings/*.ethl 
  do
    .build/x86_64-apple-macosx10.10/debug/etherlang $f --emit-ir &> /dev/null
    if [ $? -ne 0 ]; then
      ERRORS=$(($ERRORS + 1))
      echo "Compilation failed: $f"
    fi

    solFile=${f%.*}.sol
    solc $solFile &> /dev/null
    if [ $? -ne 0 ]; then
      ERRORS=$(($ERRORS + 1))
      echo "Solc failed: $solFile"
    fi
  done
done

for f in examples/invalid/*.ethl 
do
  .build/x86_64-apple-macosx10.10/debug/etherlang $f --emit-ir &> /dev/null
  if [ $? -eq 0 ]; then
    ERRORS=$(($ERRORS + 1))
    echo "Compilation succeeded: $f"
  fi
done

if [ $ERRORS -ne 0 ]; then
  exit 1
fi
