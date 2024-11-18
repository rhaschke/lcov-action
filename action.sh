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
  docker run --rm -t -v "$DIR_THIS":/lcov -v "$BASEDIR":"$BASEDIR" \
         -v "$WORKDIR":"$WORKDIR" -w "$WORKDIR" \
         -e OUTPUT -e IN_DOCKER=1 -e LCOV_CAPTURE_ARGS "$DOCKER" /lcov/action.sh "$@"
  exit $?
}

BASEDIR=$(pwd)
DOCKER=$1
WORKDIR=$(cd "${2:-$PWD}"; pwd)
OUTPUT=${3:-"$WORKDIR/coverage.info"}
cd "$WORKDIR"


# Re-run the script in docker
if [ -n "$DOCKER" ] && [ "${IN_DOCKER:-0}" != "1" ]; then run_docker "$@"; fi
shift 3
echo "Running on dir: $PWD"
echo "Writing to: $OUTPUT"

# turn input string into an array
eval "LCOV_CAPTURE_ARGS=(${LCOV_CAPTURE_ARGS})"
echo "lcov --capture args:" "${LCOV_CAPTURE_ARGS[@]}"

step "" sudo apt-get -qq update
step "" sudo apt-get install -q -y lcov

step "Capture coverage info" lcov --quiet --capture "${LCOV_CAPTURE_ARGS[@]}" --directory "$PWD" --output-file "$OUTPUT"

step "Extract repository files" lcov --quiet --extract "$OUTPUT" "$PWD/*" --output-file "$OUTPUT"

if [ -n "$*" ]; then
  step "Remove files matching: $* " lcov --quiet --remove "$OUTPUT" "$@" --output-file "$OUTPUT"
fi

step "List coverage data" lcov --list "$OUTPUT"