
set -euo pipefail
pushd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null

if [[ ! -d "odin" ]]; then
	"../scripts/grab_repo.sh"                           \
		--folder "odin"                                 \
		--repo "https://github.com/botero-dev/Odin.git"  \
		--branch master
fi


if [ ! -f "odin/odin" ]; then
    pushd "odin" > /dev/null
    "./build_odin.sh" release-native
    popd > /dev/null
fi

ODIN_ROOT="$(pwd)/odin"
echo "$ODIN_ROOT/odin"
