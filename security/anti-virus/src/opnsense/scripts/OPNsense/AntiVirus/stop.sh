#!/bin/sh

set -eu
. /usr/local/opnsense/scripts/OPNsense/AntiVirus/common.sh

if ! is_running; then
    echo "antivirus not running"
    rm -f "${PID_FILE}" >/dev/null 2>&1 || true
    exit 0
fi

_pid="$(cat "${PID_FILE}")"
kill "${_pid}" >/dev/null 2>&1 || true
sleep 1
if kill -0 "${_pid}" >/dev/null 2>&1; then
    kill -9 "${_pid}" >/dev/null 2>&1 || true
fi

rm -f "${PID_FILE}" >/dev/null 2>&1 || true
echo "antivirus stopped"