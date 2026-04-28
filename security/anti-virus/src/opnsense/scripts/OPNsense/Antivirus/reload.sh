#!/bin/sh

set -eu

configctl template reload OPNsense/Antivirus

if command -v clamdscan >/dev/null 2>&1; then
    clamdscan --reload >/dev/null 2>&1 || true
elif command -v nc >/dev/null 2>&1; then
    printf "RELOAD\n" | nc -U /var/run/clamav/clamd.sock >/dev/null 2>&1 || true
fi

service c-icap onereload || service c-icap onerestart || true
configctl proxy restart
