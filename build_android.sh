export ANDROID_HOME="/home/abotero/android_sdk"
export ODIN_ANDROID_NDK="$ANDROID_HOME/ndk/27.0.12077973"
export ODIN_ROOT=/home/abotero/abotero/odin

set -e

if [ ! -d "build/android" ]; then
	cp -r "platform/android" "build/android"
	ln -s "../SDL" "build/android/app/jni/SDL"
	ln -s "../SDL_ttf" "build/android/app/jni/SDL_ttf"
	ln -s "../SDL_image" "build/android/app/jni/SDL_image"
fi

# ideally, we would compile our odin binary after gradle compiled SDL, but
# before it is packaged. But for now we just run gradle twice.

pushd build/android

./gradlew buildDebug
popd


echo "odin build android arm64"

/home/abotero/abotero/webtest/../odin/odin build src -target=linux_arm64 -subtarget=android -build-mode=shared \
	-extra-linker-flags:"-Lbuild/android/app/build/intermediates/cxx/Debug/4z245n3s/obj/local/arm64-v8a" \
	-out:"build/android/app/libs/arm64-v8a/libmain.so" # -show-system-calls

echo "odin build android arm32"

/home/abotero/abotero/webtest/../odin/odin build src -target=linux_arm32 -subtarget=android -build-mode=shared \
	-extra-linker-flags:"-Lbuild/android/app/build/intermediates/cxx/Debug/4z245n3s/obj/local/armeabi-v7a" \
	-out:"build/android/app/libs/armeabi-v7a/libmain.so" #-show-system-calls

# -show-system-calls
# -show-timings

echo "finished compiling, gradle install now"

pushd build/android

./gradlew installDebug
popd
