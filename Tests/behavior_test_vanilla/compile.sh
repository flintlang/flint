#! /bin/sh

rm -rf test/contracts
mkdir test/contracts
for f in *.flint; do
  [ -f "$f" ] || break
  swift run flintc $f --emit-ir --ir-output test/contracts/
done
cd test
touch contracts/Migrations.sol
echo "pragma solidity ^0.4.2; contract Migrations {}" > contracts/Migrations.sol
