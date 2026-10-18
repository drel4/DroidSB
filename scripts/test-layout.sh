#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
layout_binary="$(mktemp)"
trap 'rm -f "$layout_binary"' EXIT
cc -std=c11 -Wall -Wextra -Werror -ISources tests/recording-layout.c -o "$layout_binary"
"$layout_binary"
echo 'PASS: full/compact recording chip, clock preservation, boundary widths and no overlap'
