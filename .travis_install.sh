#! /bin/bash

ROOTDIR=$(git rev-parse --show-toplevel)
TOOLSDIR="${ROOTDIR}/tools"

mkdir "$TOOLSDIR" || true

SWIFT="${TOOLSDIR}/swift-4.0.3-RELEASE-ubuntu14.04"
if [ ! -e  "$SWIFT" ]; then
  wget https://swift.org/builds/swift-4.0.3-release/ubuntu1404/swift-4.0.3-RELEASE/swift-4.0.3-RELEASE-ubuntu14.04.tar.gz -O $TOOLSDIR/swift.tar.gz
  tar xzf "${TOOLSDIR}/swift.tar.gz" -C "${TOOLSDIR}"
  rm -rf "${TOOLSDIR}/swift.tar.gz"
fi
mv "${TOOLSDIR}/swift-4.0.3-RELEASE-ubuntu14.04/usr/bin/swift" $TOOLSDIR
rm -r "${TOOLSDIR}/swift-4.0.3-RELEASE-ubuntu14.04" $TOOLSDIR
