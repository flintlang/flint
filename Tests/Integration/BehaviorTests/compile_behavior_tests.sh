#! /bin/bash

for t in tests/*; do
  rm -rf $t/test/contracts
  mkdir $t/test/contracts

  echo "Compile $t"
  ../../../.build/release/flintc  --skip-verifier $t/*.flint --emit-ir --ir-output $t/test/contracts/
  cp $t/*.sol $t/test/contracts &> /dev/null
  rm -rf ./bin

  for f in $t/*.flint; do
    [ -f "$f" ] || break
    echo "Compile Flint file '$f'"
  done

  echo "pragma solidity ^0.4.25; contract Migrations {}" > $t/test/contracts/Migrations.sol

done
