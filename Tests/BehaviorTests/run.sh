#! /bin/sh

NUM_FAILED=0

for dir in */; do
  cd $dir
  rm -rf test/contracts
  mkdir test/contracts
  swift run flintc *.flint --emit-ir --ir-output test/contracts/
  cd test
  touch contracts/Migrations.sol
  echo "pragma solidity ^0.4.2; contract Migrations {}" > contracts/Migrations.sol
  truffle test
  if [ $? != 0 ]; then
    NUM_FAILED=$NUM_FAILED+1
  fi
  cd ../../
done

if [ $NUM_FAILED != 0 ]; then
  exit 1
fi
