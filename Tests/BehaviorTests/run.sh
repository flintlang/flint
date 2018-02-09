#! /bin/sh

NUM_FAILED=0

for dir in */; do
  cd $dir
  ./compile.sh
  cd test
  truffle test
  if [ $? != 0 ]; then
    NUM_FAILED=$NUM_FAILED+1
  fi
  cd ../../
done

if [ $NUM_FAILED != 0 ]; then
  exit 1
fi
