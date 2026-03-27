#!/usr/bin/env bash

set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null


if [[ ! -d "SDL" ]]; then
	../scripts/grab_repo.sh                             \
		--folder "SDL"                                 \
		--repo "https://github.com/libsdl-org/SDL.git" \
		--branch release-3.4.2

fi

