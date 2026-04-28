#!/bin/sh

configctl template reload OPNsense/Antivirus || exit 1
service c-icap onereload || exit 1
configctl proxy restart || exit 1
