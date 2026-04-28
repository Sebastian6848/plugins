#!/bin/sh

USER=clamav
GROUP=clamav
PERMS=0755
DIRS="
/var/db/clamav
/var/run/clamav
/var/log/clamav
/tmp/c-icap/templates/virus_scan/en
"

for DIR in ${DIRS}; do
	if [ -L ${DIR} ]; then
		DIRS="${DIRS} $(realpath ${DIR})"
	fi
done

for DIR in ${DIRS}; do
	mkdir -p ${DIR}
	chown -R ${USER}:${GROUP} ${DIR}
	chmod ${PERMS} ${DIR}
done

if [ -f /usr/local/share/c_icap/templates/virus_scan/en/VIRUS_FOUND ]; then
	cp -f /usr/local/share/c_icap/templates/virus_scan/en/VIRUS_FOUND /tmp/c-icap/templates/virus_scan/en/VIRUS_FOUND
	chmod 0644 /tmp/c-icap/templates/virus_scan/en/VIRUS_FOUND
fi
