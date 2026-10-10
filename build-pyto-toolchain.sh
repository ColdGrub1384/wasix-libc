#!/usr/bin/env bash

cd "$(dirname "$0")"
set -e

sh build32-ehpic.sh
sh build-shared-libraries.sh

mv clang32-ehpic/lib/wasm32-unknown-wasip1 clang32-ehpic/lib/wasm32-pyto-wasip1 || true
mv clang32-ehpic/finclude/flang/wasm32-unknown-wasip1 clang32-ehpic/finclude/flang/wasm32-pyto-wasip1 || true

rsync -az clang32-ehpic pyto/Documents/.local/share
rsync -az sysroot32-ehpic pyto/Documents/.local/lib

cd pyto
tar czf ../wasix-sdk.tar.gz \
    --exclude='.gitignore' \
    --exclude='.DS_Store' \
    --exclude='__MACOSX' \
    --exclude='.git' \
    Documents

