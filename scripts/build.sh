#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export THEOS="${THEOS:-$HOME/theos}"
toolchain_args=()
if [[ -n "${DROIDSB_TOOLCHAIN:-}" ]]; then
    toolchain_args+=("SDKBINPATH=$DROIDSB_TOOLCHAIN/bin")
fi
python3 scripts/check-source.py
make clean "${toolchain_args[@]}"
make package FINALPACKAGE=1 "${toolchain_args[@]}" "$@"
for package in packages/*.deb; do
    python3 scripts/verify-package.py "$package"
done
