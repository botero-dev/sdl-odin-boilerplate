#!/usr/bin/env bash

set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null


if [[ ! -d "SDL_image" ]]; then
	../scripts/grab_repo.sh                                   \
		--folder "SDL_image"                                  \
		--repo "https://github.com/libsdl-org/SDL_image.git"  \
		--commit b78b999a9bca6e164e2d419a728b00cd52f80f81

fi
