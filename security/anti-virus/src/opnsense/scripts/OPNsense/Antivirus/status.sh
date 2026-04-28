#!/bin/sh

if [ -S /var/run/clamav/clamd.sock ]; then
	clamd="running"
else
	clamd="stopped"
fi

if sockstat -l | grep -q "1344"; then
	cicap="running"
else
	cicap="stopped"
fi

if grep -q "^icap_service .*avscan" /usr/local/etc/squid/pre-auth/00-antivirus-icap.conf 2>/dev/null; then
	squid_icap="active"
else
	squid_icap="inactive"
fi

if [ -f /var/run/clamav/freshclam.pid ]; then
	freshclam="running"
else
	freshclam="stopped"
fi

if command -v sigtool >/dev/null 2>&1 && [ -f /var/db/clamav/daily.cvd ]; then
	sig_version=$(sigtool --info /var/db/clamav/daily.cvd 2>/dev/null | awk -F': ' '/^Version/ {print $2; exit}')
	sig_updated=$(sigtool --info /var/db/clamav/daily.cvd 2>/dev/null | awk -F': ' '/^Build time/ {print $2; exit}')
else
	sig_version=""
	sig_updated=""
fi

echo "{\"clamd\":\"${clamd}\",\"cicap\":\"${cicap}\",\"squid_icap\":\"${squid_icap}\",\"sig_version\":\"${sig_version}\",\"sig_updated\":\"${sig_updated}\",\"freshclam\":\"${freshclam}\"}"
