#!/bin/sh

if [ "${1:-}" = "--action" ]; then
	case "${2:-}" in
		read_rules)
			exec /usr/local/opnsense/scripts/OPNsense/AppIdentification/backend.php read_rules
			;;
		write_rules)
			exec /usr/local/opnsense/scripts/OPNsense/AppIdentification/backend.php --legacy-write "${3:-}"
			;;
		reload)
			exec /usr/local/opnsense/scripts/OPNsense/AppIdentification/backend.php reload
			;;
		status)
			exec /usr/local/opnsense/scripts/OPNsense/AppIdentification/backend.php status
			;;
	esac
fi

exec /usr/local/opnsense/scripts/OPNsense/AppIdentification/backend.php --legacy-generate "$@"
