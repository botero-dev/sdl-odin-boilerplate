#!/usr/bin/env bash
# Copyright Andrés Botero 2025
#
set -euo pipefail

source "scripts/build_utils.sh"


# your environment should have:
#  - clang
#  - cmake
#  - emsdk install latest && source emsdk_env

PROJECT=${1:-}
if [[ "$PROJECT" = "" ]]; then
	echo "Usage: ./build.sh <project>"
	exit 1
fi

# ensure we have odin toolchain
ODIN=$("./vendor/odin.sh")

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${TARGET:-}" = "" ]]; then
	if [[ "$(uname)" = "Linux" ]]; then
		export TARGET="linux"
	else
		export TARGET="win"
	fi
fi

set_target "$TARGET" # sets environment variables


./vendor/sdl.sh
make_cmake_library vendor/SDL SDL3  \
	-DSDL_X11_XTEST=OFF             \
	-DSDL_TEST_LIBRARY=OFF 

./vendor/sdl_image.sh
make_cmake_library vendor/SDL_image SDL3_image  \
	-DSDL3_DIR="$BUILD_CMAKE_PATH/SDL3"         \
	-DSDLIMG_AVIF=OFF 
	# -DSDLIMAGE_VENDORED=true 

./vendor/sdl_ttf.sh
make_cmake_library vendor/SDL_ttf SDL3_ttf  \
	-DSDL3_DIR="$BUILD_CMAKE_PATH/SDL3"         \
	-DSDLTTF_VENDORED=OFF                  \
	-DSDLTTF_SAMPLES=false


compile_cmd=("$ODIN" build "$PROJECT" "-collection:engine=engine")

if [[ "$TARGET" = "linux" ]]; then

	rpath_var='$ORIGIN/lib'
	runtime_lib_flag="-Wl,-rpath,'$rpath_var'"
	compile_lib_flag="-L$INSTALL_PATH/lib"
	compile_cmd+=(
		-extra-linker-flags:"$compile_lib_flag $runtime_lib_flag"
	)
fi


mkdir -p "$PACKAGE_PATH"

if [[ "$TARGET" = "linux" ]]; then

	compile_cmd+=(
		-debug
		-vet
		-vet-tabs
		-strict-style
		-vet-style
		-warnings-as-errors
		-disallow-do
		-out:"$PACKAGE_PATH/$PROJECT.bin"
	)

elif [[ "$TARGET" = "win" ]]; then

	compile_cmd+=(
		-debug
		-out:"$PACKAGE_PATH/$PROJECT.exe"
	)

elif [[ "$TARGET" = "web" ]]; then
	mkdir -p "$BUILD_OBJ_PATH/web"

	compile_cmd+=(
		-target:js_wasm32
		-define:ODIN_DEFAULT_TO_EMSCRIPTEN_ALLOCATOR=true
		-build-mode:obj
		-debug
		-out:"$BUILD_OBJ_PATH/game.wasm.o"
#      -show-system-calls
	)
fi

echo "Compiling"

echo "${compile_cmd[@]}"
"${compile_cmd[@]}"


echo "Packaging"

if [[ "$TARGET" = "win" ]]; then
	echo "Copying .dll files."
	INSTALL_PATH_BASH=$(to_bash_path "$INSTALL_PATH")
	PACKAGE_PATH_BASH=$(to_bash_path "$PACKAGE_PATH")
	cp "$INSTALL_PATH_BASH/bin/"* "$PACKAGE_PATH_BASH"


elif [[ "$TARGET" = "linux" ]]; then
	echo "Copying .so files."
	command=(
		cp -r "$INSTALL_PATH/lib" "$PACKAGE_PATH"
	)
	echo "${command[@]}"
	"${command[@]}"


elif [[ "$TARGET" = "web" ]]; then
	source_emsdk

	link_cmd=(\
		emcc \
		-o "$PACKAGE_PATH/index.html" \
		"$BUILD_OBJ_PATH/game.wasm.o" \
		"src/clay-odin/wasm/clay.o" \
		"$INSTALL_PATH/lib/$SDL_LIBRARY" \
		"$INSTALL_PATH/lib/$SDLIMG_LIBRARY" \
		"$INSTALL_PATH/lib/$SDLTTF_LIBRARY" \
		--shell-file "platform/web/index_template.html" \
		-sERROR_ON_UNDEFINED_SYMBOLS=0 \
		-sFETCH \
		-sASSERTIONS=1\
		-sALLOW_MEMORY_GROWTH\
		-g\
		-O1\
		)

	echo "${link_cmd[@]}"
	"${link_cmd[@]}"

	cp "platform/web/odin.js" "$PACKAGE_PATH"
fi



echo "Preparing 'content' folder"


PACKAGE_CONTENT_PATH="$PACKAGE_PATH/content"
if [ -L "$PACKAGE_CONTENT_PATH" ] && [ -e "$PACKAGE_CONTENT_PATH" ]; then
    echo "Valid symlink"
elif [ -d "$PACKAGE_CONTENT_PATH" ]; then
    echo "Content is directory (not symlink). Skipping"
else
	echo "creating symlink to content folder"
	rm -f "$PACKAGE_CONTENT_PATH"
	ln -s "$REPO_ROOT/content" "$PACKAGE_CONTENT_PATH"
fi
