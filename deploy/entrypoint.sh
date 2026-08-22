#!/usr/bin/env bash
# Entrypoint for the slipstream-server container.
# Builds the CLI invocation from environment variables so the image can be
# driven entirely through docker-compose / `docker run -e`.
set -euo pipefail

DATA_DIR="${DATA_DIR:-/data}"
CERT_PATH="${CERT_PATH:-${DATA_DIR}/cert.pem}"
KEY_PATH="${KEY_PATH:-${DATA_DIR}/key.pem}"
RESET_SEED_PATH="${RESET_SEED_PATH:-${DATA_DIR}/reset-seed}"

DNS_LISTEN_HOST="${DNS_LISTEN_HOST:-::}"
DNS_LISTEN_PORT="${DNS_LISTEN_PORT:-53}"
TARGET_ADDRESS="${TARGET_ADDRESS:-127.0.0.1:5201}"
MAX_CONNECTIONS="${MAX_CONNECTIONS:-256}"
IDLE_TIMEOUT_SECONDS="${IDLE_TIMEOUT_SECONDS:-60}"

if [[ -z "${DOMAIN:-}" ]]; then
    echo "error: DOMAIN is required (set DOMAIN=your.tunnel.domain)" >&2
    exit 2
fi

mkdir -p "${DATA_DIR}"

args=(
    --dns-listen-host "${DNS_LISTEN_HOST}"
    --dns-listen-port "${DNS_LISTEN_PORT}"
    --target-address "${TARGET_ADDRESS}"
    --cert "${CERT_PATH}"
    --key "${KEY_PATH}"
    --reset-seed "${RESET_SEED_PATH}"
    --max-connections "${MAX_CONNECTIONS}"
    --idle-timeout-seconds "${IDLE_TIMEOUT_SECONDS}"
)

# DOMAIN may hold several comma-separated domains; each becomes its own --domain.
IFS=',' read -ra _domains <<< "${DOMAIN}"
for d in "${_domains[@]}"; do
    d="$(echo "${d}" | xargs)" # trim surrounding whitespace
    [[ -n "${d}" ]] && args+=(--domain "${d}")
done

# Optional non-DNS UDP fallback endpoint.
if [[ -n "${FALLBACK:-}" ]]; then
    args+=(--fallback "${FALLBACK}")
fi

# Pass through any extra raw flags verbatim (space-separated).
if [[ -n "${EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    args+=(${EXTRA_ARGS})
fi

exec slipstream-server "${args[@]}"
