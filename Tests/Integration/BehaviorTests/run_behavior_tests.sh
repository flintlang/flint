#! /bin/sh

NUM_FAILED=0

echo "Compiling Flint sources"
#./compile_behavior_tests.sh
cd tests

for dir in *; do
  echo "Testing $dir"
  cd $dir/test
  truffle test
  if [ $? != 0 ]; then
    NUM_FAILED=$NUM_FAILED+1
  fi
  cd ../..
done

if [ $NUM_FAILED != 0 ]; then
  exit 1
fi
