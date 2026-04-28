#!/bin/sh

service c-icap onestop || exit 1
: > /usr/local/etc/squid/pre-auth/00-antivirus-icap.conf || exit 1
configctl proxy restart || exit 1
