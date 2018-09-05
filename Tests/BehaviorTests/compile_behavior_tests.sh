#! /bin/bash

for t in tests/*; do
  rm -rf $t/test/contracts
  mkdir $t/test/contracts

  echo "Compile $t"
  ../../.build/release/flintc $t/*.flint --emit-ir --ir-output $t/test/contracts/ --quiet

  #for f in $t/*.flint; do
    #[ -f "$f" ] || break
    #echo "Compile Flint file '$f'"
  #done

  echo "pragma solidity ^0.4.2; contract Migrations {}" > $t/test/contracts/Migrations.sol
done
