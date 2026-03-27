
set -euo pipefail

##   Script to fetch and patch dependencies:
# This script pulls from a repo, and applies patches directly in the folder
# named after the dependency. Ideally you should be able to delete the
# dependency folder and run this script, and get the exact content that is
# already pushed into the repo. For patching dependencies, you can edit files in
# place, but in the end you should make the changes here so we can always update
# a dependency or replicate the changes on top of a freshly checked out repo.


# example invocation:
# ./scripts/grab_repo.sh                             \
#	--folder "SDL"                                 \
#	--repo "https://github.com/libsdl-org/SDL.git" \
#	--branch release-3.4.2                         \
#	--keep-git-history

# Parse arguments
FOLDER=""
REPO=""
BRANCH=""
COMMIT=""
KEEP_GIT_HISTORY=""

while [[ $# -gt 0 ]]; do
	case $1 in
		--folder)
			FOLDER="$2"
			shift 2
			;;
		--repo)
			REPO="$2"
			shift 2
			;;
		--branch)
			BRANCH="$2"
			shift 2
			;;
		--commit)
			COMMIT="$2"
			shift 2
			;;
		--keep-git-history)
			KEEP_GIT_HISTORY="true"
			shift
			;;
		*)
			echo "Unknown option: $1"
			exit 1
			;;
	esac
done

# Validate required arguments
if [ -z "$FOLDER" ] || [ -z "$REPO" ]; then
	echo "Error: --folder and --repo are required"
	exit 1
fi

if [ ! -d "$FOLDER" ]; then
	if [ -n "$COMMIT" ]; then
		git clone "$REPO" "$FOLDER"
		cd "$FOLDER"
		git checkout "$COMMIT"
		cd ..
	elif [ -n "$BRANCH" ]; then
		git clone "$REPO" --branch "$BRANCH" --depth 1 "$FOLDER"
	else
		git clone "$REPO" "$FOLDER"
	fi

	# if we do `rm -r $FOLDER/.git` we would be in a state where we can push to our
	# repo. If we don't then we would leave the working copy in a state ready to
	# push patches upstream.

	if [ -z "$KEEP_GIT_HISTORY" ]; then
		rm -rf "$FOLDER/.git"
	fi
fi
