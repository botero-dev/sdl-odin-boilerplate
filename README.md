Odin + SDL + WASM + Android Boilerplate
=======================================

This project is a framework for building cross-platform applications using SDL library and Odin Language. 

A gallery application is developed as a test environment to implement the many systems needed to run:

- Main loop to grab input, do idle processing, layout and rendering.
- Event handling like pointer routing and keyboard/gamepad/tv remote navigation.
- UI Layout
- 2D drawing of antialiased lines and rectangles with borders and rounded corners.
- Drawing state stack for applying 2D transforms and color modulation when drawing. (broken atm)
- AsyncIO loading from storage and threaded decoding of image assets.
- Compiles in Windows, Linux, Android and WASM.

## Compiling

Install dependencies:
- LLVM on Linux/macOS
- Visual Studio on Windows
- CMake


### How to build:

Build scripts will grab submodules if needed.

Linux or Windows (run from git bash):

	./build.sh

Web:

	TARGET=web ./build.sh

Android:

	./build_android.sh # builds and pushes apk to the device
