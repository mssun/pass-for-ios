#!/bin/bash

set -euox pipefail

GOPENPGP_VERSION="v2.1.10"

export GOPATH="$(pwd)/go"
export PATH="$PATH:$GOPATH/bin"

OUTPUT_PATH="go/dist"
CHECKOUT_PATH="go/checkout"
GOPENPGP_PATH="$CHECKOUT_PATH/gopenpgp"

mkdir -p "$OUTPUT_PATH"
mkdir -p "$CHECKOUT_PATH"

go env -w GO111MODULE=auto
go get golang.org/x/mobile/cmd/gomobile
gomobile init

git clone --depth 1 --branch "$GOPENPGP_VERSION" git@github.com:ProtonMail/gopenpgp.git "$GOPENPGP_PATH"

git apply patch/gnu-dummy.patch --directory "$GOPENPGP_PATH"

sed -i '' 's/build android/echo "Skipping Android build."/g' "$GOPENPGP_PATH/build.sh"

(cd "$GOPENPGP_PATH" && ./build.sh)

cp -R "$GOPENPGP_PATH/dist/Gopenpgp.xcframework" "$OUTPUT_PATH"

