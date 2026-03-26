#!/bin/sh

set -eu

IP="${1:-}"
TABLE="industrial_av_block"

if [ -z "${IP}" ]; then
    echo "missing ip"
    exit 1
fi

/sbin/pfctl -t "${TABLE}" -T delete "${IP}" >/dev/null 2>&1 || true
echo "unblocked ${IP}"
