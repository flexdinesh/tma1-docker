#!/bin/sh
set -eu

# TMA1 expects the GreptimeDB executable below its data directory. Keep the
# immutable image copy elsewhere so a named volume cannot hide it, then seed or
# refresh the volume atomically when the image changes.
data_dir="${TMA1_DATA_DIR:-/var/lib/tma1}"
source_bin="/usr/local/lib/tma1/greptime"
bin_dir="${data_dir}/bin"
target_bin="${bin_dir}/greptime"
runtime_uid="${TMA1_RUNTIME_UID:-10001}"
runtime_gid="${TMA1_RUNTIME_GID:-10001}"

case "$runtime_uid" in
    ''|*[!0-9]*)
        echo "TMA1_RUNTIME_UID must be a non-zero numeric UID" >&2
        exit 1
        ;;
esac
case "$runtime_gid" in
    ''|*[!0-9]*)
        echo "TMA1_RUNTIME_GID must be a non-zero numeric GID" >&2
        exit 1
        ;;
esac
if [ "$runtime_uid" -eq 0 ]; then
    echo "TMA1_RUNTIME_UID must be non-zero; TMA1 does not run as root" >&2
    exit 1
fi
if [ "$runtime_gid" -eq 0 ]; then
    echo "TMA1_RUNTIME_GID must be non-zero; TMA1 does not run with the root group" >&2
    exit 1
fi

mkdir -p "$bin_dir"

# Named volumes retain numeric ownership across image and host changes. Migrate
# an existing volume only when the configured runtime identity changes; session
# artifact mounts live outside data_dir and are never modified here.
data_uid="$(stat -c '%u' "$data_dir")"
data_gid="$(stat -c '%g' "$data_dir")"
if [ "$data_uid" != "$runtime_uid" ] || [ "$data_gid" != "$runtime_gid" ]; then
    chown -R "$runtime_uid:$runtime_gid" "$data_dir"
fi

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
    chown "$runtime_uid:$runtime_gid" "$temp_bin"
    mv "$temp_bin" "$target_bin"
fi

exec gosu "$runtime_uid:$runtime_gid" env HOME="$HOME" "$@"
