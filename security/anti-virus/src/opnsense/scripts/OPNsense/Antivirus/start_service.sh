#!/bin/sh

SERVICE="$1"

case "${SERVICE}" in
	clamd)
		/usr/local/opnsense/scripts/OPNsense/Antivirus/setup.sh || exit 1
		service clamav_clamd onestart || exit 1
		;;
	cicap)
		/usr/local/opnsense/scripts/OPNsense/Antivirus/setup.sh || exit 1
		service c-icap onestart || exit 1
		;;
	freshclam)
		/usr/local/opnsense/scripts/OPNsense/Antivirus/setup.sh || exit 1
		service clamav_freshclam onestart || exit 1
		;;
	squid_icap)
		configctl template reload OPNsense/Antivirus || exit 1
		configctl proxy restart || exit 1
		;;
	*)
		echo "Unsupported service"
		exit 1
		;;
esac

echo "done"
