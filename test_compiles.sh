#! /bin/bash

ERRORS=0

for dir in valid warnings
do
  for f in examples/$dir/*.ethl 
  do
    .build/x86_64-apple-macosx10.10/debug/etherlang $f --emit-ir &> /dev/null
    if [ $? -ne 0 ]; then
      ERRORS=$(($ERRORS + 1))
      echo "Compilation failed: $f"
    fi

    filePath=${f%.*}
    fileName=`basename $filePath`
    solFile="examples/$dir/bin/$fileName/$fileName.sol"
    solc $solFile &> /dev/null
    if [ $? -ne 0 ]; then
      echo "Solc failed: $solPath"
    fi

    rm -r "examples/$dir/bin"
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
