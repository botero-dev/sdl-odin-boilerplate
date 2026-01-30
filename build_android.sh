#!/bin/bash

export ANDROID_HOME="/home/abotero/android_sdk"
export ODIN_ANDROID_NDK="$ANDROID_HOME/ndk/27.0.12077973"
export ODIN_ROOT=/home/abotero/abotero/odin

set -e
set -x

PROJECT_ROOT=$(pwd)

if [ ! -d "build/android" ]; then
	cp -r "platform/android" "build/android"
	ln -s "$PROJECT_ROOT/../SDL" "build/android/app/jni/SDL"
	ln -s "$PROJECT_ROOT/../SDL_ttf" "build/android/app/jni/SDL_ttf"
	ln -s "$PROJECT_ROOT/../SDL_image" "build/android/app/jni/SDL_image"
fi

# ideally, we would compile our odin binary after gradle compiled SDL, but
# before it is packaged. But for now we just run gradle twice.

pushd build/android

./gradlew buildDebug -info
popd



BUILD_CONFIG="debug"
APP_PATH="build/android/app"
BUILD_LIB_PATH="$APP_PATH/build/intermediates/ndkBuild/$BUILD_CONFIG/obj/local"
BUILD_OUT_PATH="$APP_PATH/libs"

echo "odin build android arm64"
mkdir -p "$BUILD_OUT_PATH/arm64-v8a"

"$ODIN_ROOT/odin" build src -target=linux_arm64 -subtarget=android -build-mode=shared \
	-extra-linker-flags:"-L$BUILD_LIB_PATH/arm64-v8a" \
	-out:"$BUILD_OUT_PATH/arm64-v8a/libmain.so" # -show-system-calls

echo "odin build android arm32"
mkdir -p "$BUILD_OUT_PATH/armeabi-v7a"

"$ODIN_ROOT/odin" build src -target=linux_arm32 -subtarget=android -build-mode=shared \
	-extra-linker-flags:"-L$BUILD_LIB_PATH/armeabi-v7a" \
	-out:"$BUILD_OUT_PATH/armeabi-v7a/libmain.so" #-show-system-calls

# -show-system-calls
# -show-timings

echo "finished compiling, gradle install now"

pushd build/android

./gradlew installDebug -info
popd
