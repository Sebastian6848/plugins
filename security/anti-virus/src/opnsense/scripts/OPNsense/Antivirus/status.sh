#!/bin/sh

json_escape()
{
    printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

service_state()
{
    if service "$1" onestatus >/dev/null 2>&1 || service "$1" status >/dev/null 2>&1; then
        echo "running"
    else
        echo "stopped"
    fi
}

CLAMD="stopped"
if [ -S /var/run/clamav/clamd.sock ]; then
    CLAMD="running"
fi

CICAP="stopped"
if sockstat -4 -l 2>/dev/null | awk '{print $6}' | grep -qE '(^|:)1344$'; then
    CICAP="running"
elif service c-icap onestatus >/dev/null 2>&1 || service c-icap status >/dev/null 2>&1; then
    CICAP="running"
fi

SQUID_ICAP="unknown"
if [ -s /usr/local/etc/squid/post-auth/antivirus_icap.conf ]; then
    SQUID_ICAP="active"
elif [ -f /usr/local/etc/squid/post-auth/antivirus_icap.conf ]; then
    SQUID_ICAP="inactive"
fi

FRESHCLAM="$(service_state clamav_freshclam)"
SIG_VERSION=""
SIG_UPDATED=""

if command -v sigtool >/dev/null 2>&1; then
    SIG_VERSION="$(sigtool --info /var/db/clamav/main.cvd /var/db/clamav/main.cld 2>/dev/null | awk -F: '/^Version:/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
fi

if [ -f /var/log/clamav/freshclam.log ]; then
    SIG_UPDATED="$(awk 'NF {line=$0} END {print line}' /var/log/clamav/freshclam.log)"
fi

printf '{'
printf '"clamd":"%s",' "$(json_escape "${CLAMD}")"
printf '"cicap":"%s",' "$(json_escape "${CICAP}")"
printf '"squid_icap":"%s",' "$(json_escape "${SQUID_ICAP}")"
printf '"sig_version":"%s",' "$(json_escape "${SIG_VERSION}")"
printf '"sig_updated":"%s",' "$(json_escape "${SIG_UPDATED}")"
printf '"freshclam":"%s"' "$(json_escape "${FRESHCLAM}")"
printf '}\n'
