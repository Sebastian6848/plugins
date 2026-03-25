#!/bin/sh

. /usr/local/opnsense/scripts/OPNsense/NdpiAudit/common.sh

load_conf
ensure_dirs

BINARY="$(find_binary)" || {
    echo "ndpiReader binary not found" >&2
    exit 1
}

cmd="${BINARY} -i ${MIRROR_IFACE} ${JSON_OUTPUT_ARG}"

if [ -n "${MAX_FLOWS}" ]; then
    cmd="${cmd} --max-flows ${MAX_FLOWS}"
fi

if [ -n "${MAX_PACKETS_PER_FLOW}" ]; then
    cmd="${cmd} --max-packets-per-flow ${MAX_PACKETS_PER_FLOW}"
fi

if [ -n "${TLS_FINGERPRINT_DB}" ]; then
    cmd="${cmd} --ja4-db ${TLS_FINGERPRINT_DB}"
fi

if [ -n "${TCP_FINGERPRINT_DB}" ]; then
    cmd="${cmd} --tcp-fingerprint-db ${TCP_FINGERPRINT_DB}"
fi

if [ -n "${PROTOCOL_FINGERPRINT_DB}" ]; then
    cmd="${cmd} --proto-db ${PROTOCOL_FINGERPRINT_DB}"
fi

if [ -n "${ENGINE_ARGS}" ]; then
    cmd="${cmd} ${ENGINE_ARGS}"
fi

exec /usr/bin/env NDPI_ACTION_MODE="${ACTION_MODE}" /bin/sh -c "${cmd}" >> "${LOG_FILE}" 2>> /var/log/ndpi_audit.err
