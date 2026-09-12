#!/usr/bin/env bash

set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

if [[ ! -d "odin" ]]; then
	"../scripts/grab_repo.sh"                           \
		--folder "odin"                                 \
		--repo "https://github.com/botero-dev/Odin.git"  \
		--branch master
fi


if [ ! -f "odin/odin" ] && [ ! -f "odin/odin.exe" ]; then
	echo "Compiling Odin compiler..." 2>&1
    pushd "odin" > /dev/null
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            cmd //c build.bat release
            ;;
        *)
            "./build_odin.sh" release-native
            ;;
    esac
    popd > /dev/null
fi
