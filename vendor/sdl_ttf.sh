#!/usr/bin/env bash

set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null


if [[ ! -d "SDL_ttf" ]]; then
	../scripts/grab_repo.sh                                   \
		--folder "SDL_ttf"                                   \
		--repo "https://github.com/libsdl-org/SDL_ttf.git"   \
		--branch release-3.2.2

	# TODO:
	#  SDL_ttf/external/download.sh
	#  rm SDL_ttf/external/*/.git
fi
