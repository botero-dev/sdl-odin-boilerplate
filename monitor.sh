
export AB_SKIP_REBUILD_LIBS=1

set -euo pipefail

if [[ "$#" == "0" ]]; then
    echo "Usage: $0 <folders to watch...>"
    exit 1
fi

#: "${ACTION:=TARGET=web build.sh"
: "${ACTION:=./build.sh dxf}"

args=($@)
echo "Watching for changes in ${args[@]}"

while true; do
    inotifywait -r -e modify,create,delete,move "${args[@]}" >/dev/null 2>&1
	clear
    echo "Change detected at $(date). Running '$ACTION'"

    sleep 0.1 # in case many files were saved in batch, 

    if ! eval "${ACTION}"; then
        echo "${ACTION} exited with code $?"
    fi

done
