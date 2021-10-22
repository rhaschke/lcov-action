#!/bin/bash
set -eo pipefail

function step() {
  title="${1:-$*}"
  shift 1
  local BLUE="\033[0;34m";
  local NOCOLOR="\033[0m";

  echo -e "##[group]${BLUE}$title${NOCOLOR}"
  "$@"
  echo -e "##[endgroup]"
}

function run_docker {
  DIR_THIS=$(dirname "${BASH_SOURCE[0]}")

  echo "Using docker image: $DOCKER"
  docker run --rm -t -v "$DIR_THIS":/lcov -v "$WORKDIR":"$WORKDIR" -w "$WORKDIR" \
         -e OUTPUT -e IN_DOCKER=1 "$DOCKER" /lcov/action.sh "$@"
  exit $?
}

DOCKER=$1
WORKDIR=$(cd "${2:-$PWD}"; pwd)
OUTPUT=${3:-"$WORKDIR/coverage.info"}
cd "$WORKDIR"

# Re-run the script in docker
if [ -n "$DOCKER" ] && [ "${IN_DOCKER:-0}" != "1" ]; then run_docker "$@"; fi
shift 3
echo "Running on dir: $PWD"
echo "Writing to: $OUTPUT"

step "" sudo apt-get -qq update
step "" sudo apt-get install -q -y lcov

step "Capture coverage info" lcov --capture --directory "$PWD" --output-file "$OUTPUT"

step "Extract repository files" lcov --extract "$OUTPUT" "$PWD/*" --output-file "$OUTPUT"

if [ -n "$*" ]; then
  step "Remove files matching: $* " lcov --remove "$OUTPUT" "$@" --output-file "$OUTPUT"
fi

step "List coverage data" lcov --list "$OUTPUT"