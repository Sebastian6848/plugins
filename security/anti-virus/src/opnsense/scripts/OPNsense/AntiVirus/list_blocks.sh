#!/bin/sh

set -eu

TABLE="industrial_av_block"

/sbin/pfctl -t "${TABLE}" -T show 2>/dev/null || true
