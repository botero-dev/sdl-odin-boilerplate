

set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

if [[ ! -d "emsdk" ]]; then
	"../scripts/grab_repo.sh"                           \
		--folder "emsdk"                                 \
		--repo "https://github.com/emscripten-core/emsdk.git"

    pushd "emsdk"
	./emsdk install latest
	./emsdk activate latest
fi



