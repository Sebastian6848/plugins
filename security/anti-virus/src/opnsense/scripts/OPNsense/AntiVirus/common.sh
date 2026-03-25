#!/bin/sh

CONF_FILE="/usr/local/etc/antivirusd.conf"
PID_FILE="/var/run/antivirus/antivirusd.pid"
RUN_DIR="/var/run/antivirus"
EXTRACT_DIR="/var/run/av_extract"
LOG_FILE="/var/log/antivirusd.log"
PYTHON_BIN="/usr/local/bin/python3"
DAEMON_SCRIPT="/usr/local/opnsense/scripts/OPNsense/AntiVirus/antivirusd.py"

ensure_dirs()
{
    mkdir -p "${RUN_DIR}" "${EXTRACT_DIR}" /var/log
    chmod 700 "${RUN_DIR}" "${EXTRACT_DIR}"
}

is_running()
{
    if [ ! -f "${PID_FILE}" ]; then
        return 1
    fi

    _pid="$(cat "${PID_FILE}" 2>/dev/null)"
    [ -n "${_pid}" ] && kill -0 "${_pid}" 2>/dev/null
}