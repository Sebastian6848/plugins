#!/bin/sh

CONF_FILE="/usr/local/etc/ndpi-audit/ndpi-audit.conf"
PID_FILE="/var/run/ndpi_audit.pid"

find_binary()
{
    if [ -n "${BINARY_PATH}" ] && [ -x "${BINARY_PATH}" ]; then
        echo "${BINARY_PATH}"
        return 0
    fi

    for candidate in \
        /usr/local/bin/ndpiReader \
        /usr/local/sbin/ndpiReader
    do
        if [ -x "${candidate}" ]; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
}

load_conf()
{
    if [ -f "${CONF_FILE}" ]; then
        . "${CONF_FILE}"
    fi

    : "${ENABLED:=0}"
    : "${MIRROR_IFACE:=lo1}"
    : "${LOG_FILE:=/var/log/ndpi_audit.log}"
    : "${MAX_FLOWS:=100000}"
    : "${ACTION_MODE:=audit}"
    : "${MAX_PACKETS_PER_FLOW:=20}"
    : "${JSON_OUTPUT_ARG:=--audit-json}"
    : "${ENGINE_ARGS:=}"
}

ensure_dirs()
{
    install -d -m 0755 /usr/local/etc/ndpi-audit
    install -d -m 0755 /var/log
    touch "${LOG_FILE}"
    chmod 0640 "${LOG_FILE}"
}

ensure_mirror_interface()
{
    if ! /sbin/ifconfig "${MIRROR_IFACE}" >/dev/null 2>&1; then
        /sbin/ifconfig "${MIRROR_IFACE}" create >/dev/null 2>&1 || return 1
    fi
    return 0
}

daemon_running()
{
    [ -f "${PID_FILE}" ] || return 1
    pid="$(cat "${PID_FILE}" 2>/dev/null)"
    [ -n "${pid}" ] || return 1
    /bin/kill -0 "${pid}" >/dev/null 2>&1
}
