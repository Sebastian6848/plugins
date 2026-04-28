#!/bin/sh

mkdir -p /var/db/opnsense-antivirus
chmod 750 /var/db/opnsense-antivirus

mkdir -p /var/run/c-icap
chown -R c_icap:c_icap /var/run/c-icap
chmod 750 /var/run/c-icap

mkdir -p /tmp/c-icap/templates/virus_scan/en
chmod -R 755 /tmp/c-icap

mkdir -p /var/db/clamav /var/run/clamav /var/log/clamav
chown -R clamav:clamav /var/db/clamav /var/run/clamav /var/log/clamav
chmod 755 /var/db/clamav /var/run/clamav /var/log/clamav
