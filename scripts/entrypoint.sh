#!/bin/sh
set -eu

# TMA1 expects the GreptimeDB executable below its data directory. Keep the
# immutable image copy elsewhere so a named volume cannot hide it, then seed or
# refresh the volume atomically when the image changes.
data_dir="${TMA1_DATA_DIR:-/var/lib/tma1}"
source_bin="/usr/local/lib/tma1/greptime"
bin_dir="${data_dir}/bin"
target_bin="${bin_dir}/greptime"

mkdir -p "$bin_dir"

replace_bin=1
if [ -f "$target_bin" ]; then
    source_sha="$(sha256sum "$source_bin")"
    source_sha="${source_sha%% *}"
    target_sha="$(sha256sum "$target_bin")"
    target_sha="${target_sha%% *}"
    if [ "$source_sha" = "$target_sha" ]; then
        replace_bin=0
    fi
fi

if [ "$replace_bin" -eq 1 ]; then
    temp_bin="${target_bin}.tmp.$$"
    cp "$source_bin" "$temp_bin"
    chmod 0755 "$temp_bin"
    mv "$temp_bin" "$target_bin"
fi

exec "$@"
