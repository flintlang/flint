#! /bin/sh

NUM_FAILED=0

echo "Compiling Flint sources"
./compile_behavior_tests.sh

for dir in tests/*; do
  pushd . > /dev/null
  cd $dir/test
  echo "Testing $dir"
  truffle test
  if [ $? != 0 ]; then
    NUM_FAILED=$NUM_FAILED+1
  fi
  popd > /dev/null
done

if [ $NUM_FAILED != 0 ]; then
  exit 1
fi
