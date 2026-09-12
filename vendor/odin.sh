#!/usr/bin/env bash

set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

if [[ ! -d "odin" ]]; then
	"../scripts/grab_repo.sh"                           \
		--folder "odin"                                 \
		--repo "https://github.com/botero-dev/Odin.git"  \
		--branch master
fi


if [ ! -f "odin/odin" ]; then
	echo "Compiling Odin compiler..." 2>&1
    pushd "odin" > /dev/null
    "./build_odin.sh" release-native
    popd > /dev/null
fi
