#!/usr/bin/env bash

pushd clay/bindings/odin
./build-clay-lib.sh
popd

rm -rf ../src/clay-odin
cp -r clay/bindings/odin/clay-odin ../src/clay-odin
