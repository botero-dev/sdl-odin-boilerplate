Odin + SDL + WASM + Android Boilerplate
=======================================

This project is a framework for building cross-platform applications using SDL library and Odin Language. 

A gallery application is developed as a test environment to implement the many systems needed to run:

- Main loop to grab input, do idle processing, layout and rendering.
- Event handling like pointer routing and keyboard/gamepad/tv remote navigation.
- UI Layout with Clay.
- 2D drawing of antialiased lines and rectangles with borders and rounded corners.
- Drawing state stack for applying 2D transforms and color modulation when drawing.
- AsyncIO loading from storage and threaded decoding of image assets.
- Compiles in Windows, Linux, Android and WASM.

### How to build:

You need to compile clay dependency first as its not integrated into other build scripts yet.

	./vendor/clay.sh

You need to have SDL repo and Odin compiler in the parent folder. This requirement will be lifted in the future.

Linux or Windows (run from git bash):

	./build.sh

Web:

	TARGET=web ./build.sh

Android:

	./build_android.sh # builds and pushes apk to the device
