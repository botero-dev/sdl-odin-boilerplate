#! /bin/bash
# Copyright Andrés Botero 2025
#
set -e

# first ensure that you have:
#  - clang
#  - odin
#  - cmake
#  - emsdk install latest
#  - source emsdk_env
#  - clone https://github.com/libsdl-org/SDL.git
#  - cd SDL && git checkout release-3.2.24
#

if [[ "$(uname)" = "Linux" ]]; then
	SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
	SCRIPT_PATH="c:/abotero/webtest"
fi
ODIN_PATH="$SCRIPT_PATH/../odin"

SDL_PATH="$SCRIPT_PATH/../SDL"
SDLIMG_PATH="$SCRIPT_PATH/../SDL_image"
SDLTTF_PATH="$SCRIPT_PATH/../SDL_ttf"

# git clone emsdk
# ./emsdk install latest
# ./emsdk activate latest
# you don't need to source emsdk_env as we do here manually
EMSDK_PATH="$SCRIPT_PATH/../emsdk"

if [[ "$TARGET" = "" ]]; then
	if [[ "$(uname)" = "Linux" ]]; then
		TARGET="linux"
	else
		TARGET="win"
	fi
fi

source_emsdk() {
	if [ -z "$EMSDK" ]; then
		echo "Loading emsdk environment"
		source "$EMSDK_PATH/emsdk_env.sh"
	fi
}

cmake_cmd() {
	if [[ "$TARGET" = "web" ]]; then
		source_emsdk
		echo emcmake cmake "$@"
		emcmake cmake "$@"
	else
		echo cmake "$@"
		cmake "$@"
	fi
}

BUILD_PATH="$SCRIPT_PATH/build"
BUILD_CONFIG="Debug"

# ensure that SDL is built
BUILD_SRC_PATH="$BUILD_PATH/src/$TARGET"
BUILD_OBJ_PATH="$BUILD_PATH/obj/$TARGET"
INSTALL_PATH="$BUILD_PATH/lib/$TARGET"
#BUILD_LIB_PATH="$INSTALL_PATH/lib"
PACKAGE_PATH="$BUILD_PATH/package/$TARGET"

PREFIX=""

SUFFIX=".ext"
if [[ "$TARGET" = "linux" ]]; then
	SUFFIX=".so"
	PREFIX="lib"
fi
if [[ "$TARGET" = "win" ]]; then
	SUFFIX=".lib"
fi
if [[ "$TARGET" = "web" ]]; then
	PREFIX="lib"
	SUFFIX=".a"
fi

#PREFIX="$PREFIX/$BUILD_CONFIG"

SDL_LIBRARY="${PREFIX}SDL3${SUFFIX}"
SDLIMG_LIBRARY="${PREFIX}SDL3_image${SUFFIX}"
SDLTTF_LIBRARY="${PREFIX}SDL3_ttf${SUFFIX}"

if [ ! -e "$INSTALL_PATH/lib/$SDL_LIBRARY" ]; then
    mkdir -p "$BUILD_SRC_PATH/sdl"
    pushd "$BUILD_SRC_PATH/sdl"

	cmake_cmd "$SDL_PATH" -DCMAKE_INSTALL_PREFIX="$INSTALL_PATH" -DSDL_X11_XTEST=OFF -DSDL_TEST_LIBRARY=OFF
    cmake --build . --config "$BUILD_CONFIG" --parallel
	cmake --install . --config "$BUILD_CONFIG"

	popd
fi

if [ ! -e "$INSTALL_PATH/lib/$SDLIMG_LIBRARY" ]; then
    mkdir -p "$BUILD_SRC_PATH/sdl_image"
    pushd "$BUILD_SRC_PATH/sdl_image"

    cmake_cmd "$SDLIMG_PATH" -DSDL3_DIR="$BUILD_SRC_PATH/sdl" -DCMAKE_INSTALL_PREFIX="$INSTALL_PATH" -DSDLIMG_AVIF=OFF
    cmake --build . --config "$BUILD_CONFIG" --parallel
	cmake --install . --config "$BUILD_CONFIG"

	popd
fi

if [ ! -e "$INSTALL_PATH/lib/$SDLTTF_LIBRARY" ]; then
    mkdir -p "$BUILD_SRC_PATH/sdl_ttf"
    pushd "$BUILD_SRC_PATH/sdl_ttf"
    cmake_cmd "$SDLTTF_PATH" -DSDL3_DIR="$BUILD_SRC_PATH/sdl" -DSDLTTF_SAMPLES=false -DSDLTTF_VENDORED=true -DCMAKE_INSTALL_PREFIX="$INSTALL_PATH"
    cmake --build . --config "$BUILD_CONFIG" --parallel
	cmake --install . --config "$BUILD_CONFIG"

	popd
fi


echo "Compiling"

compile_cmd=("$ODIN_PATH/odin" build src)

if [[ "$TARGET" = "linux" ]]; then
	compile_cmd+=(
		-extra-linker-flags:"-L$INSTALL_PATH/lib"
	)
fi


mkdir -p "$PACKAGE_PATH"

if [[ "$TARGET" = "linux" ]]; then

	compile_cmd+=(
		-debug
		-out:"$PACKAGE_PATH/game.bin"
	)

elif [[ "$TARGET" = "win" ]]; then

	compile_cmd+=(
		-debug
		-out:"$PACKAGE_PATH/game.exe"
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

echo "${compile_cmd[@]}"
"${compile_cmd[@]}"

if [[ "$TARGET" = "win" ]]; then
	INSTALL_PATH_BASH=$(echo "$INSTALL_PATH" | sed 's|^\([A-Za-z]\):/|/\1/|')
	PACKAGE_PATH_BASH=$(echo "$PACKAGE_PATH" | sed 's|^\([A-Za-z]\):/|/\1/|')
	cp "$INSTALL_PATH_BASH/bin/"* "$PACKAGE_PATH_BASH"

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
echo "done"


PACKAGE_CONTENT_PATH="$PACKAGE_PATH/content"
if [ -L "$PACKAGE_CONTENT_PATH" ] && [ -e "$PACKAGE_CONTENT_PATH" ]; then
    echo "Valid symlink"
elif [ -d "$PACKAGE_CONTENT_PATH" ]; then
    echo "Content is directory (not symlink). Skipping"
else
	echo "creating symlink to content folder"
	rm -f "$PACKAGE_CONTENT_PATH"
	ln -s "$SCRIPT_PATH/content" "$PACKAGE_CONTENT_PATH"
fi
