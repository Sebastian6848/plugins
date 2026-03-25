#!/bin/sh

set -eu
. /usr/local/opnsense/scripts/OPNsense/AntiVirus/common.sh

ensure_dirs

/usr/local/sbin/configctl template reload OPNsense/AntiVirus >/dev/null 2>&1 || true
/usr/local/etc/rc.d/clamav_clamd start >/dev/null 2>&1 || true

if is_running; then
    echo "antivirus already running"
    exit 0
fi

daemon -p "${PID_FILE}" -o "${LOG_FILE}" \
    "${PYTHON_BIN}" "${DAEMON_SCRIPT}" -c "${CONF_FILE}"

echo "antivirus started"