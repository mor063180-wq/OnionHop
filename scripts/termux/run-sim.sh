#!/bin/bash
set -euo pipefail

# Run a published CLI build with a minimal Termux-like environment:
# private HOME, no desktop session, no extra environment variables.
CLI_DIR="${1:?usage: run-sim.sh <publish-dir> [cli args...]}"
shift
SIM_HOME="$(mktemp -d)"
mkdir -p "$SIM_HOME/tmp"
exec env -i HOME="$SIM_HOME" TMPDIR="$SIM_HOME/tmp" PATH="/usr/bin:/bin" \
  TERM="${TERM:-xterm}" "$CLI_DIR/OnionHopV3.Cli" "$@"
