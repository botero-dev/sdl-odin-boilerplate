Odin + SDL + WASM + Android Boilerplate
=======================================

You need to compile clay separately as its not integrated into other build scripts yet.

	pushd vendor && ./clay.sh && popd

Linux:

	./build.sh

Web:

	TARGET=web ./build.sh

Android:

	./build_android.sh
