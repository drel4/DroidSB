#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export THEOS="${THEOS:-$HOME/theos}"
toolchain_args=()
if [[ -n "${DROIDSB_TOOLCHAIN:-}" ]]; then
    toolchain_args+=("SDKBINPATH=$DROIDSB_TOOLCHAIN/bin")
fi
python3 scripts/check-source.py
bash scripts/test-layout.sh
make clean "${toolchain_args[@]}"
build_stamp="$(mktemp)"
trap 'rm -f "$build_stamp"' EXIT
make package FINALPACKAGE=1 "${toolchain_args[@]}" "$@"
built_count=0
while IFS= read -r -d '' package; do
    python3 scripts/verify-package.py "$package"
    built_count=$((built_count + 1))
done < <(find packages -maxdepth 1 -name '*.deb' -newer "$build_stamp" -print0)
[[ "$built_count" -gt 0 ]] || { echo 'No new package produced' >&2; exit 1; }
