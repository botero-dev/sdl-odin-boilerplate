#!/usr/bin/env bash

set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")"

if [ ! -d "clay" ]; then
	./scripts/grab_repo.sh                              \
		 --folder "clay"                                \
		 --repo "https://github.com/nicbarker/clay.git" \
		 --commit 76ec3632d80c145158136fd44db501448e7b17c4

	pushd clay
	git apply "../clay-01-pointer-fix.patch"
	git apply "../clay-02-libraries.patch"
	popd
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
