#!/bin/sh

SOCKET="/var/run/clamav/clamd.sock"

configctl template reload OPNsense/Antivirus || exit 1

if [ ! -S "${SOCKET}" ]; then
	service clamav-clamd onestart || exit 1
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

service c-icap onestart || exit 1
configctl proxy restart || exit 1
