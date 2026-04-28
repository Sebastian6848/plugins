#!/bin/sh

set -eu

SQUID_ICAP_CONF="/usr/local/etc/squid/post-auth/antivirus_icap.conf"
service antivirus-logparser onestop || true

configctl proxy restart || true
service c-icap onestop || true
service clamav_clamd onestop || true
service clamav_freshclam onestop || true

mkdir -p "$(dirname "${SQUID_ICAP_CONF}")"
: > "${SQUID_ICAP_CONF}"
configctl proxy restart || true
