#! /bin/sh

for t in tests/*; do
  rm -rf $t/test/contracts
  mkdir $t/test/contracts

  for f in $t/*.flint; do
    [ -f "$f" ] || break
    echo "Compile Flint file '$f'"
    ../../.build/release/flintc $f --emit-ir --ir-output $t/test/contracts/
  done

  echo "pragma solidity ^0.4.2; contract Migrations {}" > $t/test/contracts/Migrations.sol
done

