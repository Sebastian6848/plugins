#!/bin/sh

set -eu

IP="${1:-}"
TTL="${2:-3600}"
TABLE="industrial_av_block"

if [ -z "${IP}" ]; then
    echo "missing ip"
    exit 1
fi

if ! echo "${TTL}" | grep -Eq '^[0-9]+$'; then
    TTL=3600
fi

/sbin/pfctl -t "${TABLE}" -T add "${IP}" >/dev/null
logger -t antivirus "blocked source ${IP} in table ${TABLE} ttl=${TTL}s"

(
    sleep "${TTL}"
    /sbin/pfctl -t "${TABLE}" -T delete "${IP}" >/dev/null 2>&1 || true
) &

echo "blocked ${IP}"