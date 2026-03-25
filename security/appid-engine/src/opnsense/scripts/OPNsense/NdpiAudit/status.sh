#!/bin/sh

. /usr/local/opnsense/scripts/OPNsense/NdpiAudit/common.sh

if daemon_running; then
    echo "ndpi audit is running"
else
    echo "ndpi audit is not running"
fi

exit 0
