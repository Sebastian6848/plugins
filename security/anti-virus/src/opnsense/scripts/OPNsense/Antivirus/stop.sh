#!/bin/sh

service c-icap onestop || exit 1
: > /usr/local/etc/squid/post-auth/antivirus_icap.conf || exit 1
configctl proxy restart || exit 1
