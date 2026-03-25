#!/bin/sh

set -eu
/bin/sh /usr/local/opnsense/scripts/OPNsense/AntiVirus/stop.sh >/dev/null 2>&1 || true
exec /bin/sh /usr/local/opnsense/scripts/OPNsense/AntiVirus/start.sh