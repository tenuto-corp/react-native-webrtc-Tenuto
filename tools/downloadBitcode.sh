#!/bin/bash

set -euo pipefail

THIS_DIR=$(cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)

# PACKAGE_VERSION=$(cat ${THIS_DIR}/../package.json \
#   | grep "\"version\":" \
#   | head -1 \
#   | awk -F: '{ print $2 }' \
#   | sed 's/[",]//g' \
#   | tr -d '[[:space:]]')

PACKAGE_VERSION="1.89.1" # 원래는 87버전이었는데, 해당 파일이 존재하지 않아 89로 업데이트했습니다.

WEBRTC_DL="https://s3.ap-northeast-2.amazonaws.com/tenuto.dev/${PACKAGE_VERSION}/WebRTC.tar.xz"

pushd ${THIS_DIR}/../apple

# Cleanup
rm -rf WebRTC.xcframework WebRTC.dSYMs

# Download
echo "Downloading files..."
echo $PACKAGE_VERSION
curl -L ${WEBRTC_DL} | tar Jxf -
echo "Done!"

popd