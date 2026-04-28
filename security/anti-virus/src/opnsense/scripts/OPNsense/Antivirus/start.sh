#!/bin/sh

set -eu

SCRIPT_DIR="/usr/local/opnsense/scripts/OPNsense/Antivirus"
SQUID_ICAP_CONF="/usr/local/etc/squid/post-auth/antivirus_icap.conf"
CLAMD_SOCKET="/var/run/clamav/clamd.sock"

if ! pkg info -e os-squid >/dev/null 2>&1; then
    echo "os-squid plugin is required"
    exit 1
fi

if pkg info -e os-clamav >/dev/null 2>&1; then
    echo "warning: os-clamav is installed and may conflict with this plugin"
fi

if pkg info -e os-c-icap >/dev/null 2>&1; then
    echo "warning: os-c-icap is installed and may overwrite this plugin's c-icap configuration"
fi

mkdir -p /var/run/clamav /var/log/clamav /var/run/c-icap /var/log/c-icap /var/db/antivirus
mkdir -p "$(dirname "${SQUID_ICAP_CONF}")"
"${SCRIPT_DIR}/db_init.py"
chown -R clamav:clamav /var/run/clamav /var/log/clamav /var/db/clamav 2>/dev/null || true
chown -R c_icap:c_icap /var/run/c-icap /var/log/c-icap 2>/dev/null || true

configctl template reload OPNsense/Antivirus
touch "${SQUID_ICAP_CONF}"

if [ ! -f /var/db/clamav/main.cvd ] && [ ! -f /var/db/clamav/main.cld ]; then
    /usr/local/sbin/freshclam --no-warnings || true
fi

service clamav_clamd onestart

count=0
while [ ! -S "${CLAMD_SOCKET}" ] && [ "${count}" -lt 120 ]; do
    sleep 1
    count=$((count + 1))
done

if [ ! -S "${CLAMD_SOCKET}" ]; then
    echo "clamd socket did not appear within 120 seconds"
    exit 1
fi

service c-icap onestart
configctl proxy restart
service clamav_freshclam onestart

service antivirus-logparser onestart || daemon -f -p /var/run/antivirus_logparser.pid "${SCRIPT_DIR}/log_parser.py"
