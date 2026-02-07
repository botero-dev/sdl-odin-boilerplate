#!/usr/bin/env bash

set -ex
pushd "$(dirname "${BASH_SOURCE[0]}")"

##   Script to fetch and patch dependencies:
# This script pulls from a repo, and applies patches directly in the folder
# named after the dependency. Ideally you should be able to delete the
# dependency folder and run this script, and get the exact content that is
# already pushed into the repo. For patching dependencies, you can edit files in
# place, but in the end you should make the changes here so we can always update
# a dependency or replicate the changes on top of a freshly checked out repo.

if [ ! -d "clay" ]; then

	git clone /home/abotero/abotero/clay

	pushd clay
	git apply "../clay-01-pointer-fix.patch"
	git apply "../clay-02-libraries.patch"
	popd

	# if we do `rm -r clay/.git` we would be in a state where we can push to our
	# repo. If we don't then we would leave the working copy in a state ready to
	# push patches upstream.

	rm -rf clay/.git

fi

pushd clay/bindings/odin
if uname | grep -q "MINGW64"; then
	rm -f clay-odin/windows/clay.lib
	mkdir -p clay-odin/windows
	clang -c -DCLAY_IMPLEMENTATION -o clay-odin/windows/clay.lib -ffreestanding -target x86_64-pc-windows-msvc -fuse-ld=llvm-lib -static -O3 clay.c

else
	./build-clay-lib.sh
fi
popd

rm -rf ../src/clay-odin
cp -r clay/bindings/odin/clay-odin ../src/clay-odin
