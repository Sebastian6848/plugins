#!/bin/sh

set -eu
. /usr/local/opnsense/scripts/OPNsense/AntiVirus/common.sh

if is_running; then
    if [ -S /var/run/clamav/clamd.sock ]; then
        echo "running (clamd socket ok)"
    else
        echo "degraded (antivirusd running, clamd socket missing)"
    fi
else
    if [ -S /var/run/clamav/clamd.sock ]; then
        echo "stopped (clamd socket ok)"
    else
        echo "stopped (clamd socket missing)"
    fi
fi