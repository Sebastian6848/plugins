#!/bin/sh

. /usr/local/opnsense/scripts/OPNsense/NdpiAudit/common.sh

load_conf

RULE_FILE="/usr/local/etc/ndpi-audit/mirror.rules"
ANCHOR_NAME="ndpi-audit/mirror"

if ! /sbin/pfctl -s Anchors 2>/dev/null | /usr/bin/grep -q "^ndpi-audit"; then
    echo "ndpi-audit anchor not active yet; run filter reload first"
    exit 0
fi

if [ "${ENABLED}" != "1" ]; then
    /sbin/pfctl -a "${ANCHOR_NAME}" -F rules >/dev/null 2>&1 || true
    echo "ndpi-audit anchor flushed"
    exit 0
fi

ensure_mirror_interface || {
    echo "failed to create mirror interface ${MIRROR_IFACE}"
    exit 1
}

if [ ! -f "${RULE_FILE}" ]; then
    echo "mirror rules not found: ${RULE_FILE}"
    exit 1
fi

/sbin/pfctl -a "${ANCHOR_NAME}" -f "${RULE_FILE}"
