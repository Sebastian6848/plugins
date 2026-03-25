#!/bin/sh

set -eu
. /usr/local/opnsense/scripts/OPNsense/AntiVirus/common.sh

CLAMD_SOCKET="/var/run/clamav/clamd.sock"
CLAMD_CONF="/usr/local/etc/clamd.conf"
CONFIGCTL_BIN="/usr/local/sbin/configctl"

check_clamd_runtime()
{
    if [ ! -x /usr/local/sbin/clamd ]; then
        echo "error: clamd binary missing (/usr/local/sbin/clamd)"
        echo "hint: reinstall clamav packages (clamav, os-clamav)"
        return 1
    fi

    if command -v ldd >/dev/null 2>&1; then
        _missing_libs="$(ldd /usr/local/sbin/clamd 2>/dev/null | awk '/not found/ {print $1}' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
        if [ -n "${_missing_libs}" ]; then
            echo "error: clamd runtime dependency missing: ${_missing_libs}"
            echo "hint: repair pkg state and reinstall required libraries"
            return 1
        fi
    fi

    return 0
}

start_clamd()
{
    if [ -S "${CLAMD_SOCKET}" ]; then
        return 0
    fi

    if [ -x /usr/local/etc/rc.d/clamav_clamd ]; then
        /usr/local/etc/rc.d/clamav_clamd onestart >/dev/null 2>&1 || true
    fi

    if [ ! -S "${CLAMD_SOCKET}" ] && [ -x "${CONFIGCTL_BIN}" ]; then
        "${CONFIGCTL_BIN}" clamav start >/dev/null 2>&1 || true
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

if ! check_clamd_runtime; then
    exit 1
fi

if [ -x "${CONFIGCTL_BIN}" ]; then
    "${CONFIGCTL_BIN}" template reload OPNsense/AntiVirus >/dev/null 2>&1 || true
    "${CONFIGCTL_BIN}" template reload OPNsense/ClamAV >/dev/null 2>&1 || true
fi

if [ -x /usr/local/opnsense/scripts/OPNsense/ClamAV/setup.sh ]; then
    /bin/sh /usr/local/opnsense/scripts/OPNsense/ClamAV/setup.sh >/dev/null 2>&1 || true
fi

start_clamd

if ! wait_for_clamd_socket; then
    echo "error: clamd socket missing (${CLAMD_SOCKET}), ClamAV engine is not running"
    echo "hint: verify ${CLAMD_CONF} is valid and clamd package/service is available"
    exit 1
fi

if is_running; then
    echo "antivirus already running"
    exit 0
fi

daemon -p "${PID_FILE}" -o "${LOG_FILE}" \
    "${PYTHON_BIN}" "${DAEMON_SCRIPT}" -c "${CONF_FILE}"

echo "antivirus started"