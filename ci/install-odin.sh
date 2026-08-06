#!/bin/sh
# Install an Odin toolchain, the way CI installs it.
#
#   ./ci/install-odin.sh pinned ~/odin        what this project claims to support
#   ./ci/install-odin.sh latest ~/odin        the newest release
#   ./ci/install-odin.sh 2 ~/odin             the third-newest (0 is newest)
#   ./ci/install-odin.sh dev-2026-07a ~/odin  that exact tag
#   ./ci/install-odin.sh --resolve pinned     print the tag and stop
#
# Prints the directory to use as ODIN_ROOT on stdout. Everything else goes to
# stderr, so `export ODIN_ROOT=$(./ci/install-odin.sh latest ~/odin)` works.
#
# This exists as a script rather than as steps inside a workflow so that a
# contributor can install exactly what CI installed when CI disagrees with
# their machine. A toolchain difference is the first thing to rule out
# (ADR-009), and it cannot be ruled out if only a YAML file knows how.
set -e

say() { echo "$@" >&2; }

# release_json prints the release object for a spec: `latest`, an index, or a tag.
#
# The GitHub API is asked rather than a URL being built, because the asset names
# are NOT regular: one release ships `odin-macos-arm64-dev-06.tar.gz` while its
# siblings ship `odin-macos-arm64-dev-2026-06.tar.gz`. A guessed URL would work
# for months and then 404 on one release.
release_json() {
	spec="$1"
	case "$spec" in
	pinned)
		# SPEC-PLAT-032: continuous integration pins ONE combination, and it is
		# the one the project claims to support. A pull request must not go red
		# because Odin released something yesterday — that attributes a
		# toolchain change to whoever happened to push next. Drift is the
		# nightly job's question, not a contributor's.
		#
		# Moving the pin is a commit, by a person, with a probe report
		# (SPEC-PLAT-031).
		release_json "$(tr -d ' \t\n' < "$(dirname "$0")/pinned-odin.txt")"
		;;
	latest)
		curl -sSfL "https://api.github.com/repos/odin-lang/Odin/releases/latest"
		;;
	[0-9] | [0-9][0-9])
		curl -sSfL "https://api.github.com/repos/odin-lang/Odin/releases?per_page=20" |
			python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)['"$spec"']))'
		;;
	*)
		curl -sSfL "https://api.github.com/repos/odin-lang/Odin/releases/tags/$spec"
		;;
	esac
}

if [ "$1" = "--resolve" ]; then
	release_json "${2:-latest}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])'
	exit 0
fi

spec="${1:?usage: install-odin.sh <latest|index|tag> <destination>}"
destination="${2:?usage: install-odin.sh <latest|index|tag> <destination>}"

if [ -x "$destination/odin" ]; then
	say "odin is already installed in $destination"
	echo "$destination"
	exit 0
fi

case "$(uname -s)" in
Linux) platform=linux ;;
Darwin) platform=macos ;;
*) say "unsupported operating system: $(uname -s)"; exit 1 ;;
esac
case "$(uname -m)" in
x86_64 | amd64) architecture=amd64 ;;
arm64 | aarch64) architecture=arm64 ;;
*) say "unsupported architecture: $(uname -m)"; exit 1 ;;
esac

release_json "$spec" > "$destination.release.json" 2>/dev/null ||
	{ say "could not read the release list for '$spec'"; exit 1; }

# Matched by PREFIX, for the irregular-name reason above.
url=$(python3 - "$destination.release.json" "odin-$platform-$architecture" <<'PY'
import json, sys
release = json.load(open(sys.argv[1]))
prefix = sys.argv[2]
for asset in release["assets"]:
    if asset["name"].startswith(prefix):
        print(release["tag_name"], asset["browser_download_url"])
        break
else:
    print("", "")
PY
)
set -- $url
tag="$1"
download="$2"
rm -f "$destination.release.json"

if [ -z "$download" ]; then
	say "no odin-$platform-$architecture asset in release '$spec'"
	exit 1
fi

say "installing $tag for $platform-$architecture"
mkdir -p "$destination"
# The archive holds ONE top-level directory whose name matches neither the tag
# nor the asset — `odin-linux-amd64-dev-2026-07a.tar.gz` unpacks to
# `odin-linux-amd64-nightly+2026-07-10/`. Stripping it is what makes the
# destination path predictable enough to cache and to export as ODIN_ROOT.
curl -sSfL "$download" | tar -xz -C "$destination" --strip-components=1
chmod +x "$destination/odin"

say "$("$destination/odin" version)"
echo "$destination"
