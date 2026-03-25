#!/bin/sh

/bin/sh /usr/local/opnsense/scripts/OPNsense/NdpiAudit/stop.sh >/dev/null 2>&1 || true
exec /bin/sh /usr/local/opnsense/scripts/OPNsense/NdpiAudit/start.sh
