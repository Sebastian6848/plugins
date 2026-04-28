#!/bin/sh

configctl template reload OPNsense/Antivirus || exit 1
/usr/local/opnsense/scripts/OPNsense/Antivirus/setup.sh || exit 1
service clamav_freshclam onerestart || exit 1
service clamav_clamd onerestart || exit 1
service c-icap onerestart || exit 1
configctl proxy restart || exit 1
