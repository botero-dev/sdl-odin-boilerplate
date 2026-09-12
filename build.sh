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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "$REPO_ROOT" > /dev/null

git submodule update --init --recursive

# ensure we have odin toolchain
"./vendor/odin.sh"
ODIN_ROOT="$REPO_ROOT/vendor/odin"
ODIN="$ODIN_ROOT/odin"

if [[ "${TARGET:-}" = "" ]]; then
	if [[ "$(uname)" = "Linux" ]]; then
		export TARGET="linux"
	else
		export TARGET="win"
	fi
fi

set_target "$TARGET" # sets environment variables

if [[ "${AB_SKIP_REBUILD_LIBS:-0}" == 0 ]]; then

	./vendor/sdl.sh
	make_cmake_library vendor/SDL SDL3  \
		-DSDL_X11_XTEST=OFF             \
		-DSDL_TEST_LIBRARY=OFF 

	./vendor/sdl_image.sh
	make_cmake_library vendor/SDL_image SDL3_image  \
		-DSDL3_DIR="$BUILD_CMAKE_PATH/SDL3"         \
		-DSDLIMAGE_AVIF=OFF 
		# -DSDLIMAGE_VENDORED=true 

	./vendor/sdl_ttf.sh
	make_cmake_library vendor/SDL_ttf SDL3_ttf  \
		-DSDL3_DIR="$BUILD_CMAKE_PATH/SDL3"         \
		-DSDLTTF_VENDORED=ON                  \
		-DSDLTTF_SAMPLES=false

fi


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
		# -vet
		# -vet-tabs
		# -strict-style
		# -vet-style
		# -warnings-as-errors
		# -disallow-do
		-out:"$PACKAGE_PATH/$PROJECT.bin"
	)

elif [[ "$TARGET" = "win" ]]; then

	# The Odin SDL bindings import their libraries as `system:SDL3*` on Windows,
	# so point the linker at the libraries built into $INSTALL_PATH.
	INSTALL_PATH_WIN=$(to_win_path "$INSTALL_PATH")
	compile_cmd+=(
		-debug
		-out:"$PACKAGE_PATH/$PROJECT.exe"
		-extra-linker-flags:"/LIBPATH:$INSTALL_PATH_WIN/lib"
	)

	# Odin defaults to /subsystem:console on Windows, which makes Windows
	# allocate a console window for the app. Use the GUI subsystem instead,
	# unless AB_CONSOLE=1 is set (useful when debugging).
	if [[ "${AB_CONSOLE:-0}" = "1" ]]; then
		compile_cmd+=(-subsystem:console)
	else
		compile_cmd+=(-subsystem:windows)
	fi

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
		"$INSTALL_PATH/lib/libSDL3.a" \
		"$INSTALL_PATH/lib/libSDL3_image.a" \
		"$INSTALL_PATH/lib/libSDL3_ttf.a" \
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
	cp "platform/web/manifest.json" "$PACKAGE_PATH"
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
