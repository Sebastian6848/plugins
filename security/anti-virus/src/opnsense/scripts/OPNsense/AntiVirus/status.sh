#!/bin/sh

set -eu
. /usr/local/opnsense/scripts/OPNsense/AntiVirus/common.sh

if is_running; then
    echo "running"
else
    echo "stopped"
fi