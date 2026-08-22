#!/usr/bin/env bash
#
# slipstream-server one-command installer.
#
# Installs Docker if missing, pulls the pre-built slipstream-server image from
# ghcr.io, and starts a slipstream DNS-tunnel server in a container.
#
# Usage (the script asks for the domain interactively):
#   curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
#     | sudo bash
#
# Or pass it up front:
#   curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
#     | sudo bash -s -- --domain tunnel.example.com
#
# From a checkout:
#   sudo ./scripts/install.sh            # prompts for the domain
#   sudo ./scripts/install.sh --domain tunnel.example.com
#
set -euo pipefail

# ---- Defaults ----------------------------------------------------------------
IMAGE="${SLIPSTREAM_IMAGE:-ghcr.io/specflowdev/slipstream:latest}"
INSTALL_DIR="${SLIPSTREAM_INSTALL_DIR:-/opt/slipstream}"

DOMAIN=""
TARGET_ADDRESS="127.0.0.1:5201"
DNS_LISTEN_PORT="53"
FALLBACK=""
MAX_CONNECTIONS="256"
IDLE_TIMEOUT_SECONDS="60"
EXTRA_ARGS=""
ASSUME_YES="0"
FREE_PORT="1"

# ---- Output helpers ----------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET="\033[0m"; C_BOLD="\033[1m"; C_BLUE="\033[34m"
    C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_RED="\033[31m"
else
    C_RESET=""; C_BOLD=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""
fi
info()  { echo -e "${C_BLUE}==>${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}==>${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}!! ${C_RESET} $*" >&2; }
die()   { echo -e "${C_RED}error:${C_RESET} $*" >&2; exit 1; }

usage() {
    cat <<USAGE
${C_BOLD}slipstream-server installer${C_RESET}

Options:
  -d, --domain <DOMAIN>       Tunnel domain (comma-separate for several).
                              If omitted, the script asks for it interactively.
  -t, --target <HOST:PORT>    Where the server forwards decrypted traffic
                              (default: ${TARGET_ADDRESS}).
      --port <PORT>           DNS listen port (default: ${DNS_LISTEN_PORT}).
      --fallback <HOST:PORT>  Forward non-DNS UDP packets to this endpoint.
      --max-connections <N>   Max concurrent QUIC connections (default: ${MAX_CONNECTIONS}).
      --idle-timeout <SEC>    Idle connection timeout (default: ${IDLE_TIMEOUT_SECONDS}).
      --extra-args "<ARGS>"   Extra raw flags passed to slipstream-server.
      --image <IMAGE>         Docker image to use (default: ${IMAGE}).
      --install-dir <PATH>    Where to place config files (default: ${INSTALL_DIR}).
      --no-free-port          Do not touch systemd-resolved to free port 53.
  -y, --yes                   Non-interactive; assume yes to prompts.
  -h, --help                  Show this help.

Example:
  sudo ./scripts/install.sh --domain tunnel.example.com --target 127.0.0.1:1080
USAGE
}

# ---- Argument parsing --------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domain)        DOMAIN="${2:?}"; shift 2 ;;
        -t|--target)        TARGET_ADDRESS="${2:?}"; shift 2 ;;
        --port)             DNS_LISTEN_PORT="${2:?}"; shift 2 ;;
        --fallback)         FALLBACK="${2:?}"; shift 2 ;;
        --max-connections)  MAX_CONNECTIONS="${2:?}"; shift 2 ;;
        --idle-timeout)     IDLE_TIMEOUT_SECONDS="${2:?}"; shift 2 ;;
        --extra-args)       EXTRA_ARGS="${2:?}"; shift 2 ;;
        --image)            IMAGE="${2:?}"; shift 2 ;;
        --install-dir)      INSTALL_DIR="${2:?}"; shift 2 ;;
        --no-free-port)     FREE_PORT="0"; shift ;;
        -y|--yes)           ASSUME_YES="1"; shift ;;
        -h|--help)          usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
done

# ---- Preconditions -----------------------------------------------------------
require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "must run as root (use sudo)."
    fi
}

# Basic sanity check for a single domain like "tunnel.example.com".
valid_single_domain() {
    [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}$ ]]
}

# Validate a comma-separated list of domains; empty parts are rejected.
valid_domain() {
    local input="$1" part
    [[ -n "${input}" ]] || return 1
    IFS=',' read -ra _parts <<< "${input}"
    for part in "${_parts[@]}"; do
        part="$(echo "${part}" | xargs)"
        valid_single_domain "${part}" || return 1
    done
    return 0
}

prompt_domain() {
    [[ -n "${DOMAIN}" ]] && return

    # When piped (curl | bash) stdin is the script, so read from the terminal
    # directly via /dev/tty. Fall back to stdin only if it is itself a tty.
    local tty_in=""
    if [[ -r /dev/tty ]]; then
        tty_in="/dev/tty"
    elif [[ -t 0 ]]; then
        tty_in="/dev/stdin"
    fi

    if [[ "${ASSUME_YES}" == "1" || -z "${tty_in}" ]]; then
        die "no domain provided and no terminal to prompt on. Pass --domain <domain>."
    fi

    while :; do
        printf "Enter tunnel domain (e.g. tunnel.example.com): " > /dev/tty
        read -r DOMAIN < "${tty_in}" || die "failed to read domain."
        DOMAIN="$(echo "${DOMAIN}" | xargs | LC_ALL=C tr -cd 'a-zA-Z0-9.,_-')"
        if [[ -z "${DOMAIN}" ]]; then
            warn "Domain must not be empty."
            continue
        fi
        if ! valid_domain "${DOMAIN}"; then
            warn "'${DOMAIN}' does not look like a valid domain. Try again."
            continue
        fi
        break
    done
    ok "Using domain: ${DOMAIN}"
}

SUDO_KEEP=""
detect_os() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
    else
        OS_ID="unknown"
    fi
}

# ---- Docker install ----------------------------------------------------------
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        ok "Docker already installed: $(docker --version)"
        return
    fi
    info "Docker not found; installing via get.docker.com ..."
    if ! command -v curl >/dev/null 2>&1; then
        die "curl is required to install Docker; install curl and re-run."
    fi
    curl -fsSL https://get.docker.com | sh
    command -v docker >/dev/null 2>&1 || die "Docker installation failed."
    ok "Docker installed: $(docker --version)"
}

ensure_docker_running() {
    if ! docker info >/dev/null 2>&1; then
        info "Starting Docker daemon ..."
        if command -v systemctl >/dev/null 2>&1; then
            systemctl enable --now docker || true
        fi
        docker info >/dev/null 2>&1 || die "Docker daemon is not running."
    fi
}

# Resolve a working compose command ("docker compose" or "docker-compose").
COMPOSE=()
detect_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE=(docker compose)
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE=(docker-compose)
    else
        die "Docker Compose not available. Install the compose plugin and re-run."
    fi
    ok "Using compose: ${COMPOSE[*]}"
}

# ---- Setup install dir -------------------------------------------------------
SRC_DIR="${INSTALL_DIR}"

prepare_install_dir() {
    mkdir -p "${INSTALL_DIR}"
    # Write a self-contained compose file (no build needed).
    cat > "${INSTALL_DIR}/docker-compose.yml" <<COMPOSE
services:
  slipstream-server:
    image: ${IMAGE}
    container_name: slipstream-server
    restart: unless-stopped
    network_mode: host
    env_file: .env
    volumes:
      - slipstream-data:/data

volumes:
  slipstream-data:
COMPOSE
}

# ---- Compose env + up --------------------------------------------------------
write_env() {
    local env_file="${SRC_DIR}/.env"
    info "Writing ${env_file}"
    cat > "${env_file}" <<ENV
DOMAIN=${DOMAIN}
TARGET_ADDRESS=${TARGET_ADDRESS}
DNS_LISTEN_PORT=${DNS_LISTEN_PORT}
FALLBACK=${FALLBACK}
MAX_CONNECTIONS=${MAX_CONNECTIONS}
IDLE_TIMEOUT_SECONDS=${IDLE_TIMEOUT_SECONDS}
EXTRA_ARGS=${EXTRA_ARGS}
ENV
}

start_server() {
    info "Pulling slipstream-server image ..."
    docker pull "${IMAGE}"
    info "Starting slipstream-server ..."
    ( cd "${SRC_DIR}" && "${COMPOSE[@]}" up -d --force-recreate )
}

# Is anything currently listening on the DNS UDP port?
port_53_busy() {
    ss -lunH 2>/dev/null | grep -qE "[:.]${DNS_LISTEN_PORT}\b"
}

# Free the DNS port automatically. We only ever touch systemd-resolved's stub
# listener — the standard holder of :53 on Ubuntu/Debian — and we keep the
# host's own DNS working by pointing resolv.conf at the real upstream list
# before restarting. Any other process holding the port is left alone (we warn
# instead of killing it).
free_port_53() {
    [[ "${FREE_PORT}" == "1" ]] || return 0
    [[ "${DNS_LISTEN_PORT}" == "53" ]] || return 0
    port_53_busy || return 0

    if command -v systemctl >/dev/null 2>&1 \
       && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        local conf="/etc/systemd/resolved.conf"
        if grep -qiE '^[[:space:]]*DNSStubListener[[:space:]]*=[[:space:]]*no' "${conf}" 2>/dev/null; then
            : # stub already disabled; the holder is something else
        else
            info "Port 53 is held by systemd-resolved; freeing it ..."
            # Keep host DNS alive: use the real upstream resolvers, not the stub.
            if [[ -e /run/systemd/resolve/resolv.conf ]]; then
                ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
            fi
            if grep -qiE '^[[:space:]]*#?[[:space:]]*DNSStubListener' "${conf}" 2>/dev/null; then
                sed -i -E 's|^[[:space:]]*#?[[:space:]]*DNSStubListener[[:space:]]*=.*|DNSStubListener=no|' "${conf}"
            else
                printf '\nDNSStubListener=no\n' >> "${conf}"
            fi
            systemctl restart systemd-resolved || true
            sleep 1
            ok "systemd-resolved stub listener disabled; port 53 freed."
        fi
    fi

    if port_53_busy; then
        warn "UDP port ${DNS_LISTEN_PORT} is still in use by another process."
        warn "Find and stop it, then re-run:  sudo ss -lunp | grep ':${DNS_LISTEN_PORT}'"
    fi
}

# Give the container a moment, then confirm it is actually running rather than
# restarting in a crash loop (e.g. because the DNS port could not be bound).
verify_running() {
    sleep 3
    local state
    state="$(docker inspect -f '{{.State.Status}}' slipstream-server 2>/dev/null || echo unknown)"
    if [[ "${state}" != "running" ]]; then
        warn "Container is not running cleanly (state: ${state}). Recent logs:"
        docker logs --tail 15 slipstream-server 2>&1 | sed 's/^/    /' >&2 || true
        if docker logs --tail 20 slipstream-server 2>&1 | grep -qi "address already in use"; then
            warn "Port ${DNS_LISTEN_PORT} is still taken. Free it and re-run, or see 'sudo ss -lunp | grep :${DNS_LISTEN_PORT}'."
        fi
        die "slipstream-server failed to start. Fix the issue above and re-run."
    fi
}

summary() {
    echo
    ok "${C_BOLD}slipstream-server is up.${C_RESET}"
    echo "  domain         : ${DOMAIN}"
    echo "  dns listen port: ${DNS_LISTEN_PORT}/udp"
    echo "  target address : ${TARGET_ADDRESS}"
    echo "  install dir    : ${SRC_DIR}"
    echo
    echo "Manage it with:"
    echo "  cd ${SRC_DIR} && ${COMPOSE[*]} logs -f"
    echo "  cd ${SRC_DIR} && ${COMPOSE[*]} down"
}

main() {
    require_root
    prompt_domain
    detect_os
    install_docker
    ensure_docker_running
    detect_compose
    prepare_install_dir
    write_env
    free_port_53
    start_server
    verify_running
    summary
}

main "$@"
