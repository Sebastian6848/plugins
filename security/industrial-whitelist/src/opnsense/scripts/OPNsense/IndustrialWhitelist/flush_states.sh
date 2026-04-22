#!/bin/sh

set -eu

if /usr/local/opnsense/scripts/filter/kill_states.py --filter= --label=IW-HOOK >/dev/null 2>&1; then
    echo "flushed managed IW-HOOK states"
    exit 0
fi

if /sbin/pfctl -k label -k IW-HOOK >/dev/null 2>&1; then
    echo "flushed managed IW-HOOK states (pfctl fallback)"
    exit 0
fi

echo "failed to flush managed IW-HOOK states" >&2
exit 1
