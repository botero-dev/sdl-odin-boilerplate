export ODIN_ANDROID_NDK="/home/abotero/android_sdk/ndk/27.0.12077973"

#/home/abotero/abotero/webtest/../odin/odin build src -extra-linker-flags:"-L/home/abotero/abotero/webtest/build/linux/sdl/lib -L/home/abotero/abotero/webtest/build/linux/sdl_image/lib -L/home/abotero/abotero/webtest/build/linux/sdl_ttf/lib" -target=linux_arm64 -subtarget=android -build-mode=shared

# todo: compile clay with android triple aarch64-linux-android

/home/abotero/abotero/webtest/../odin/odin build src -target=linux_arm64 -subtarget=android -build-mode=shared #-extra-linker-flags:"-L/home/abotero/abotero/webtest/build/android/app/build/intermediates/cxx/Debug/4z245n3s/obj/local/arm64-v8a"

cp src.so build/android/app/jni/src/libsrc.so

#ar rcs src.a *.o
#cp src.a build/android/app/jni/src/src.a

#rm *.o