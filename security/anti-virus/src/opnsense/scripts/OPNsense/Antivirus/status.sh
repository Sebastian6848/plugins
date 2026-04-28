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

echo "{\"clamd\":\"${clamd}\",\"cicap\":\"${cicap}\"}"
