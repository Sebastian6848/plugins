#!/bin/sh

. /usr/local/opnsense/scripts/OPNsense/NdpiAudit/common.sh

load_conf

if [ "${ENABLED}" != "1" ]; then
    echo "ndpi audit disabled"
    exit 0
fi

ensure_dirs
ensure_mirror_interface || {
    echo "failed to create mirror interface ${MIRROR_IFACE}"
    exit 1
}

if daemon_running; then
    echo "ndpi audit already running"
    exit 0
fi

BINARY="$(find_binary)" || {
    echo "ndpiReader binary not found"
    exit 1
}

exec /usr/sbin/daemon -p "${PID_FILE}" -f /usr/local/opnsense/scripts/OPNsense/NdpiAudit/worker.sh
