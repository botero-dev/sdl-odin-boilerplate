#!/bin/bash

PROJECT_ROOT=$(pwd)

export ANDROID_HOME="/home/abotero/android_sdk"
export ODIN_ANDROID_NDK="$ANDROID_HOME/ndk/28.2.13676358"
export ODIN_ROOT="$PROJECT_ROOT/vendor/odin"

set -e
set -x

# TODO: ensure SDL_ttf/external/download.sh has been called
# TODO: ensure "platform/android" matches SDL repo android-project. maybe use that entirely?

target="$1"

if [ ! -d "build/android" ]; then
	mkdir -p "build"
	cp -r "platform/android" "build/android"
	ln -s "$PROJECT_ROOT/vendor/SDL" "build/android/app/jni/SDL"
	ln -s "$PROJECT_ROOT/vendor/SDL_ttf" "build/android/app/jni/SDL_ttf"
	ln -s "$PROJECT_ROOT/vendor/SDL_image" "build/android/app/jni/SDL_image"
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

"$ODIN_ROOT/odin" build "$target" -debug -collection:engine=engine -target=linux_arm64 -subtarget=android -build-mode=shared \
	-extra-linker-flags:"-L$BUILD_LIB_PATH/arm64-v8a" \
	-out:"$BUILD_OUT_PATH/arm64-v8a/libmain.so" # -show-system-calls

echo "odin build android arm32"
mkdir -p "$BUILD_OUT_PATH/armeabi-v7a"

"$ODIN_ROOT/odin" build "$target" -debug -collection:engine=engine -target=linux_arm32 -subtarget=android -build-mode=shared \
	-extra-linker-flags:"-L$BUILD_LIB_PATH/armeabi-v7a" \
	-out:"$BUILD_OUT_PATH/armeabi-v7a/libmain.so" #-show-system-calls

# -show-system-calls
# -show-timings

echo "finished compiling, gradle install now"

pushd build/android

./gradlew installDebug -info
popd
