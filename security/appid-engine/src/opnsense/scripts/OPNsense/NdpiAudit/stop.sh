#!/bin/sh

. /usr/local/opnsense/scripts/OPNsense/NdpiAudit/common.sh

if ! [ -f "${PID_FILE}" ]; then
    echo "ndpi audit not running"
    exit 0
fi

pid="$(cat "${PID_FILE}" 2>/dev/null)"
if [ -n "${pid}" ] && /bin/kill -0 "${pid}" >/dev/null 2>&1; then
    /bin/kill "${pid}" >/dev/null 2>&1 || true
    sleep 1
    if /bin/kill -0 "${pid}" >/dev/null 2>&1; then
        /bin/kill -9 "${pid}" >/dev/null 2>&1 || true
    fi
fi

rm -f "${PID_FILE}"
echo "ndpi audit stopped"
