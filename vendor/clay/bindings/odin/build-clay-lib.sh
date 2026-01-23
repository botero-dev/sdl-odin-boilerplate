
set -ex

cp ../../clay.h clay.c;

# Intel Mac
rm -f clay-odin/macos/clay-x64.a
clang -c -DCLAY_IMPLEMENTATION -o clay.o -ffreestanding -static -target x86_64-apple-darwin clay.c -fPIC -O3
ar r clay-odin/macos/clay-x64.a clay.o

# ARM Mac
rm -f clay-odin/macos/clay-arm64.a
clang -c -DCLAY_IMPLEMENTATION -g -o clay.o -static clay.c -fPIC -O3
ar r clay-odin/macos/clay-arm64.a clay.o

# x64 Windows
rm -f clay-odin/windows/clay.lib
clang -c -DCLAY_IMPLEMENTATION -o clay-odin/windows/clay.lib -ffreestanding -target x86_64-pc-windows-msvc -fuse-ld=llvm-lib -static -O3 clay.c

# Linux
rm -f clay-odin/linux/clay.a
clang -c -DCLAY_IMPLEMENTATION -o clay.o -ffreestanding -static -target x86_64-unknown-linux-gnu clay.c -fPIC -O3
ar r clay-odin/linux/clay.a clay.o

mkdir -p clay-odin/android
# Android ARM64
rm -f clay-odin/android/clay-arm64.a
clang -c -DCLAY_IMPLEMENTATION -o clay.o -ffreestanding -static -target aarch64-linux-android clay.c -fPIC -O3
ar r clay-odin/android/clay-arm64.a clay.o

# Android ARM32
rm -f clay-odin/android/clay-arm32.a
clang -c -DCLAY_IMPLEMENTATION -o clay.o -ffreestanding -static -target armv7a-linux-android clay.c -fPIC -O3
ar r clay-odin/android/clay-arm32.a clay.o

# WASM
rm -f clay-odin/wasm/clay.o
clang -c -DCLAY_IMPLEMENTATION -o clay-odin/wasm/clay.o -target wasm32 -nostdlib -static -O3 clay.c
rm clay.o;
rm clay.c;
