# !/bin/bash

VERSION=$1
BUILD=$2
DATE=`date +%Y-%m-%d`
PLATFORMS="macos linux"

if [[ -z $VERSION || -z $BUILD ]]; then
  echo "Missing version or build"
  exit 1
fi

for PLATFORM in $PLATFORMS; do
  OUT="flint-$VERSION-snapshot-$DATE-$BUILD-$PLATFORM"
  git tag -a $OUT -m "$PLATFORM $DATE development snapshot for $VERSION$BUILD"
done
