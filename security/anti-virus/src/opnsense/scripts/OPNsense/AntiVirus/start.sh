#!/bin/sh

set -eu
. /usr/local/opnsense/scripts/OPNsense/AntiVirus/common.sh

CLAMD_SOCKET="/var/run/clamav/clamd.sock"
CLAMD_CONF="/usr/local/etc/clamd.conf"

start_clamd()
{
    if [ -S "${CLAMD_SOCKET}" ]; then
        return 0
    fi

    if [ -x /usr/local/etc/rc.d/clamav_clamd ]; then
        /usr/local/etc/rc.d/clamav_clamd onestart >/dev/null 2>&1 || true
    elif /usr/local/sbin/configctl -h >/dev/null 2>&1; then
        /usr/local/sbin/configctl clamav start >/dev/null 2>&1 || true
    fi

    if [ ! -S "${CLAMD_SOCKET}" ] && [ -x /usr/local/sbin/clamd ]; then
        mkdir -p /var/run/clamav
        chown clamav:clamav /var/run/clamav >/dev/null 2>&1 || true
        /usr/local/sbin/clamd --config-file="${CLAMD_CONF}" >/dev/null 2>&1 || true
    fi
}

wait_for_clamd_socket()
{
    _retries=20
    while [ "${_retries}" -gt 0 ]; do
        if [ -S "${CLAMD_SOCKET}" ]; then
            return 0
        fi
        _retries=$(( _retries - 1 ))
        sleep 1
    done
    return 1
}

ensure_dirs

/usr/local/sbin/configctl template reload OPNsense/AntiVirus >/dev/null 2>&1 || true

if [ -x /usr/local/opnsense/scripts/OPNsense/ClamAV/setup.sh ]; then
    /bin/sh /usr/local/opnsense/scripts/OPNsense/ClamAV/setup.sh >/dev/null 2>&1 || true
fi

start_clamd

if ! wait_for_clamd_socket; then
    echo "error: clamd socket missing (${CLAMD_SOCKET}), ClamAV engine is not running"
    echo "hint: verify ${CLAMD_CONF} is valid and clamd binary/service is available"
    exit 1
fi

if is_running; then
    echo "antivirus already running"
    exit 0
fi

daemon -p "${PID_FILE}" -o "${LOG_FILE}" \
    "${PYTHON_BIN}" "${DAEMON_SCRIPT}" -c "${CONF_FILE}"

echo "antivirus started"