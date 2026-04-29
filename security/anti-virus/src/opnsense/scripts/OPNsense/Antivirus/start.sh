#!/bin/sh

SOCKET="/var/run/clamav/clamd.sock"

configctl template reload OPNsense/Antivirus || exit 1
/usr/local/opnsense/scripts/OPNsense/Antivirus/setup.sh || exit 1

if [ ! -S "${SOCKET}" ]; then
	service clamav_freshclam onestart || exit 1
	service clamav_clamd onestart || exit 1
fi

count=0
while [ ! -S "${SOCKET}" ]; do
	if [ ${count} -ge 120 ]; then
		echo "Timeout waiting for ${SOCKET}"
		exit 1
	fi
	count=$((count + 1))
	sleep 1
done

mkdir -p /var/log/c-icap
chown c_icap:c_icap /var/log/c-icap

i=0
while ! nc -z 127.0.0.1 3310 2>/dev/null; do
	sleep 1
	i=$((i + 1))
	if [ $i -ge 30 ]; then
		echo "clamd not ready after 30s, starting c-icap anyway"
		break
	fi
done

service c-icap onestart || exit 1
configctl proxy restart || exit 1
