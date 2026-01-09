export ODIN_ANDROID_NDK="/home/abotero/android_sdk/ndk/27.0.12077973"

set -e

#/home/abotero/abotero/webtest/../odin/odin build src -extra-linker-flags:"-L/home/abotero/abotero/webtest/build/linux/sdl/lib -L/home/abotero/abotero/webtest/build/linux/sdl_image/lib -L/home/abotero/abotero/webtest/build/linux/sdl_ttf/lib" -target=linux_arm64 -subtarget=android -build-mode=shared

# todo: compile clay with android triple aarch64-linux-android

/home/abotero/abotero/webtest/../odin/odin build src -target=linux_arm64 -subtarget=android -build-mode=shared -extra-linker-flags:"-L/home/abotero/abotero/webtest/build/android/app/build/intermediates/cxx/Debug/4z245n3s/obj/local/arm64-v8a"

#cp src.so build/android/app/jni/src/libs/libmain.so
cp src.so build/android/app/libs/arm64-v8a/libmain.so

pushd build/android

./gradlew installDebug
popd

#ar rcs src.a *.o
#cp src.a build/android/app/jni/src/src.a

#rm *.o


exit 0

/home/abotero/android_sdk/ndk/27.0.12077973/ndk-build \
  NDK_PROJECT_PATH=null \
  APP_BUILD_SCRIPT=/home/abotero/abotero/webtest/build/android/app/jni/Android.mk \
  NDK_APPLICATION_MK=/home/abotero/abotero/webtest/build/android/app/jni/Application.mk \
  APP_ABI=arm64-v8a \
  NDK_ALL_ABIS=arm64-v8a \
  NDK_DEBUG=1 \
  NDK_OUT=/home/abotero/abotero/webtest/build/android/app/build/intermediates/cxx/Debug/4z245n3s/obj \
  NDK_LIBS_OUT=/home/abotero/abotero/webtest/build/android/app/build/intermediates/cxx/Debug/4z245n3s/lib \
  APP_PLATFORM=android-21 \
  APP_SHORT_COMMANDS=false \
  LOCAL_SHORT_COMMANDS=false \
  -B \
  -n


/home/abotero/android_sdk/ndk/27.0.12077973/ndk-build \
  NDK_PROJECT_PATH=null \
  APP_BUILD_SCRIPT=/home/abotero/abotero/webtest/build/android/app/jni/Android.mk \
  NDK_APPLICATION_MK=/home/abotero/abotero/webtest/build/android/app/jni/Application.mk \
  APP_ABI=arm64-v8a \
  NDK_ALL_ABIS=arm64-v8a \
  NDK_DEBUG=1 \
  NDK_OUT=/home/abotero/abotero/webtest/build/android/app/build/intermediates/cxx/Debug/4z245n3s/obj \
  NDK_LIBS_OUT=/home/abotero/abotero/webtest/build/android/app/build/intermediates/cxx/Debug/4z245n3s/lib \
  APP_PLATFORM=android-21 \
  SDL3 \
  SDL3_image \
  SDL3_ttf