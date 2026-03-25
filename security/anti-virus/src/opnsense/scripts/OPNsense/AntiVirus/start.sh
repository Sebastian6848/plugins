#!/bin/sh

set -eu
. /usr/local/opnsense/scripts/OPNsense/AntiVirus/common.sh

ensure_dirs

/usr/local/sbin/configctl template reload OPNsense/AntiVirus >/dev/null 2>&1 || true

if [ -x /usr/local/opnsense/scripts/OPNsense/ClamAV/setup.sh ]; then
    /bin/sh /usr/local/opnsense/scripts/OPNsense/ClamAV/setup.sh >/dev/null 2>&1 || true
fi

if [ -x /usr/local/etc/rc.d/clamav_clamd ]; then
    /usr/local/etc/rc.d/clamav_clamd start >/dev/null 2>&1 || true
else
    /usr/local/sbin/configctl clamav start >/dev/null 2>&1 || true
fi

if [ ! -S /var/run/clamav/clamd.sock ]; then
    echo "error: clamd socket missing (/var/run/clamav/clamd.sock), ClamAV engine is not running"
    echo "hint: install/enable os-clamav plugin and verify /usr/local/etc/rc.d/clamav_clamd exists"
    exit 1
fi

if is_running; then
    echo "antivirus already running"
    exit 0
fi

daemon -p "${PID_FILE}" -o "${LOG_FILE}" \
    "${PYTHON_BIN}" "${DAEMON_SCRIPT}" -c "${CONF_FILE}"

echo "antivirus started"