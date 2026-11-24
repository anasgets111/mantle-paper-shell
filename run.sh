#!/bin/sh
# Start the paper shell with the bundled fonts visible to fontconfig.
# Usage: ./run.sh [check]   PAPER_OUTPUT=<connector> pins every panel to one output.
here=$(cd "$(dirname "$0")" && pwd)
export FONTCONFIG_FILE="$here/fonts.conf"
if [ "$1" = check ]; then exec mantle -c "$here" check; fi
exec mantle -c "$here" -d "$@"
