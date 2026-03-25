#!/bin/sh

set -u

SOCKET_PATH="/var/run/clamav/clamd.sock"
PID_PATH="/var/run/antivirus/antivirusd.pid"
STATS_PATH="/var/run/antivirus/stats.json"
LOG_PATH="/var/log/antivirusd.log"
EVENTS_LOG_PATH="/var/log/antivirus_events.log"
EXTRACT_DIR="/var/run/av_extract"

PASS_COUNT=0
FAIL_COUNT=0

log()
{
    printf '%s\n' "$*"
}

pass()
{
    PASS_COUNT=$((PASS_COUNT + 1))
    log "PASS: $*"
}

fail()
{
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "FAIL: $*"
}

run_check()
{
    _title="$1"
    shift

    if "$@" >/tmp/antivirus_selftest_cmd.out 2>&1; then
        pass "${_title}"
    else
        fail "${_title}"
        log "  output:"
        sed 's/^/    /' /tmp/antivirus_selftest_cmd.out
    fi
}

wait_for_socket()
{
    _retries="${1:-20}"
    while [ "${_retries}" -gt 0 ]; do
        if [ -S "${SOCKET_PATH}" ]; then
            return 0
        fi
        _retries=$((_retries - 1))
        sleep 1
    done
    return 1
}

pid_running()
{
    if [ ! -f "${PID_PATH}" ]; then
        return 1
    fi

    _pid="$(cat "${PID_PATH}" 2>/dev/null || true)"
    [ -n "${_pid}" ] && kill -0 "${_pid}" 2>/dev/null
}

contains_running_status()
{
    _status="$1"
    echo "${_status}" | grep -Eiq 'running|degraded'
}

get_stat_value()
{
    _key="$1"
    if [ ! -r "${STATS_PATH}" ]; then
        echo 0
        return 0
    fi
    _value="$(sed -n "s/.*\"${_key}\": *\([0-9][0-9]*\).*/\1/p" "${STATS_PATH}" | tail -n 1)"
    if [ -z "${_value}" ]; then
        echo 0
    else
        echo "${_value}"
    fi
}

wait_infected_increase()
{
    _base="$1"
    _retries="${2:-20}"
    while [ "${_retries}" -gt 0 ]; do
        _current="$(get_stat_value infected)"
        if [ "${_current}" -gt "${_base}" ]; then
            return 0
        fi
        _retries=$((_retries - 1))
        sleep 1
    done
    return 1
}

section()
{
    log ""
    log "== $* =="
}

section "Pre-clean"
configctl antivirus stop >/dev/null 2>&1 || true
rm -f "${PID_PATH}" >/dev/null 2>&1 || true

section "Start chain"
START_OUTPUT="$(configctl antivirus start 2>&1 || true)"
log "start output: ${START_OUTPUT}"

if wait_for_socket 20; then
    pass "clamd socket is available (${SOCKET_PATH})"
else
    fail "clamd socket not ready within timeout (${SOCKET_PATH})"
fi

if pid_running; then
    pass "antivirus daemon pid is alive"
else
    fail "antivirus daemon pid is missing or dead"
fi

STATUS_OUTPUT="$(configctl antivirus status 2>&1 || true)"
log "status output: ${STATUS_OUTPUT}"
if contains_running_status "${STATUS_OUTPUT}"; then
    pass "status reports running/degraded"
else
    fail "status does not report running/degraded"
fi

if [ -r "${STATS_PATH}" ] && grep -Eq '"started_at"|"queued"|"scanned"' "${STATS_PATH}"; then
    pass "stats file is readable (${STATS_PATH})"
else
    fail "stats file missing or invalid (${STATS_PATH})"
fi

section "EICAR detection"
mkdir -p "${EXTRACT_DIR}" >/dev/null 2>&1 || true
EICAR_FILE="${EXTRACT_DIR}/selftest-eicar.bin"
rm -f "${EICAR_FILE}" "${EICAR_FILE}.meta" >/dev/null 2>&1 || true

INFECTED_BEFORE="$(get_stat_value infected)"

printf 'X5O!P%%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > "${EICAR_FILE}"
cat > "${EICAR_FILE}.meta" << 'EOF'
{"source_ip":"198.51.100.10"}
EOF

if wait_infected_increase "${INFECTED_BEFORE}" 20; then
    pass "EICAR sample detected (infected counter increased)"
else
    fail "EICAR sample not detected within timeout"
fi

if [ -r "${EVENTS_LOG_PATH}" ] && tail -n 50 "${EVENTS_LOG_PATH}" | grep -Eiq 'eicar|test'; then
    pass "event log contains EICAR/test signature hint"
else
    fail "event log missing EICAR/test signature hint"
fi

section "Restart consistency"
run_check "configctl antivirus restart succeeds" configctl antivirus restart

if wait_for_socket 20; then
    pass "clamd socket is still available after restart"
else
    fail "clamd socket missing after restart"
fi

AV_COUNT="$(pgrep -fc 'antivirusd.py' 2>/dev/null || true)"
if [ -n "${AV_COUNT}" ] && [ "${AV_COUNT}" -eq 1 ]; then
    pass "single antivirusd instance after restart"
else
    fail "unexpected antivirusd instance count after restart (count=${AV_COUNT:-0})"
fi

section "Stop behavior"
run_check "configctl antivirus stop succeeds" configctl antivirus stop
sleep 1

if pgrep -f 'antivirusd.py' >/dev/null 2>&1; then
    fail "antivirusd is still running after stop"
else
    pass "antivirusd is stopped"
fi

section "Summary"
log "PASS=${PASS_COUNT} FAIL=${FAIL_COUNT}"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    log ""
    log "Last antivirusd log lines:"
    if [ -r "${LOG_PATH}" ]; then
        tail -n 40 "${LOG_PATH}" | sed 's/^/  /'
    else
        log "  ${LOG_PATH} not readable"
    fi
    exit 1
fi

exit 0