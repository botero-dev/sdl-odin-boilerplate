#!/usr/bin/env bash
# Copyright Andrés Botero 2025
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"


set_target() {
	export TARGET="$1"
	export BUILD_PATH="$REPO_ROOT/build"
	export BUILD_CMAKE_PATH="$BUILD_PATH/cmake/$TARGET"
	export INSTALL_PATH="$BUILD_PATH/$TARGET"
	export BUILD_OBJ_PATH="$BUILD_PATH/obj/$TARGET"
	export PACKAGE_PATH="$REPO_ROOT/out/$TARGET"
}

source_emsdk() {
	if [ -z "$EMSDK" ]; then
		echo "Loading emsdk environment"
		"$REPO_ROOT/vendor/emsdk.sh"
		source "$REPO_ROOT/vendor/em
		sdk/emsdk_env.sh"
	fi
}
export -f source_emsdk

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
export -f cmake_cmd

# Convert Windows path format (C:/) to Unix bash format (/C/)
to_bash_path() {
    echo "$1" | sed 's|^\([A-Za-z]\):/|/\1/|'
}
export -f to_bash_path

make_library_name() {
	if [[ "$TARGET" = "linux" ]]; then
		echo "lib$1.so"
	elif [[ "$TARGET" = "win" ]]; then
		echo "$1.lib"
	elif [[ "$TARGET" = "web" ]]; then
		echo "$1.a"
	else
		return 1
	fi
}
export -f make_library_name


export BUILD_CONFIG="Debug"



make_cmake_library() {

	lib_source=$1
	lib_name=$2
	lib_filename=$(make_library_name $lib_name)
	shift 2
	local cmake_args=("$@")

	if [ ! -e "$INSTALL_PATH/lib/$lib_filename" ]; then
		echo "Generating $INSTALL_PATH/lib/$lib_filename"
		cmake_build_dir="$BUILD_CMAKE_PATH/$lib_name"

		cmake_cmd \
			-S "$lib_source" \
			-B "$cmake_build_dir" \
			-DCMAKE_INSTALL_PREFIX="$INSTALL_PATH" \
			"${cmake_args[@]}"
		
		cmake --build "$cmake_build_dir" --config "$BUILD_CONFIG" --parallel
		cmake --install "$cmake_build_dir" --config "$BUILD_CONFIG"

	fi
}
export -f make_cmake_library