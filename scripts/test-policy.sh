#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
policy_binary="$(mktemp)"
trap 'rm -f "$policy_binary"' EXIT
cc -std=c11 -Wall -Wextra -Werror -ISources tests/status-policy.c -o "$policy_binary"
"$policy_binary"
echo 'PASS: handled-entry persistence, recording/privacy fallback, full/compact chip layout and clock preservation'
