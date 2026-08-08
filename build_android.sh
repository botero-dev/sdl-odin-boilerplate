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

# ABIs to build. Defaults to all supported; for a fast emulator-only build use:
#   ABIS=x86_64 ./build_android.sh <project>
# (x86_64 is the native ABI of most Android emulators.)
ABIS="${ABIS:-armeabi-v7a arm64-v8a x86_64}"

# Keep gradle in sync: only build the ABIs above.
abi_filter_prop="$(echo "$ABIS" | tr ' ' ',')"

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

./gradlew buildDebug -PappAbis="$abi_filter_prop" -info
popd



BUILD_CONFIG="debug"
APP_PATH="build/android/app"
BUILD_LIB_PATH="$APP_PATH/build/intermediates/ndkBuild/$BUILD_CONFIG/obj/local"
BUILD_OUT_PATH="$APP_PATH/libs"

# Clean the jniLibs output dir so stale libmain.so files from previously built
# ABIs don't leak into the APK (a mixed-ABI APK breaks loading on devices that
# prefer a different ABI than the one that contains the SDL libraries).
rm -rf "$BUILD_OUT_PATH"

for abi in $ABIS; do
	echo "odin build android $abi"
	mkdir -p "$BUILD_OUT_PATH/$abi"

	case "$abi" in
		arm64-v8a)   ODIN_TARGET="linux_arm64" ;;
		armeabi-v7a) ODIN_TARGET="linux_arm32" ;;
		x86_64)      ODIN_TARGET="linux_amd64" ;;
		x86)         ODIN_TARGET="linux_i386" ;;
		*)
			echo "error: unsupported ABI '$abi'" >&2
			exit 1
			;;
	esac

	"$ODIN_ROOT/odin" build "$target" -debug -collection:engine=engine -target="$ODIN_TARGET" -subtarget=android -build-mode=shared \
		-extra-linker-flags:"-L$BUILD_LIB_PATH/$abi" \
		-out:"$BUILD_OUT_PATH/$abi/libmain.so" # -show-system-calls
done

# -show-system-calls
# -show-timings

echo "finished compiling, gradle install now"

pushd build/android

./gradlew installDebug -PappAbis="$abi_filter_prop" -info
popd
