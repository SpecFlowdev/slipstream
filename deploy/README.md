# Docker deployment

Run a `slipstream-server` DNS tunnel in Docker with a single command.

## One-command install

On a fresh server (installs Docker if missing, builds the image, and starts
the server). The script asks for the tunnel domain interactively:

```bash
curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
  | sudo bash
```

Or pass the domain up front to skip the prompt:

```bash
curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
  | sudo bash -s -- --domain tunnel.example.com
```

From a local checkout:

```bash
sudo ./scripts/install.sh                            # prompts for the domain
sudo ./scripts/install.sh --domain tunnel.example.com
```

The installer:

1. Installs Docker + Compose if they are not present.
2. Fetches the source (or reuses the current checkout) including the picoquic
   submodule.
3. Builds the `slipstream-server` image and starts it via Docker Compose.

### Installer options

| Flag | Meaning | Default |
| --- | --- | --- |
| `-d, --domain` | Tunnel domain (comma-separate for several); prompted if omitted | asked |
| `-t, --target` | Where decrypted traffic is forwarded | `127.0.0.1:5201` |
| `--port` | DNS listen port | `53` |
| `--fallback` | Forward non-DNS UDP to this endpoint | disabled |
| `--max-connections` | Max concurrent QUIC connections | `256` |
| `--idle-timeout` | Idle connection timeout (seconds) | `60` |
| `--extra-args` | Extra raw flags for `slipstream-server` | none |
| `--ref` | Git branch/tag/commit to build | `main` |
| `--install-dir` | Checkout location | `/opt/slipstream` |
| `-y, --yes` | Non-interactive | off |

## Manual Compose usage

```bash
cd deploy
cp .env.example .env      # then edit DOMAIN etc.
docker compose up -d --build
docker compose logs -f
docker compose down
```

## Configuration

The container is driven by environment variables (set in `deploy/.env`):

| Variable | Meaning | Default |
| --- | --- | --- |
| `DOMAIN` | Tunnel domain(s), comma-separated | required |
| `TARGET_ADDRESS` | Forward decrypted traffic here | `127.0.0.1:5201` |
| `DNS_LISTEN_HOST` | DNS bind host | `::` |
| `DNS_LISTEN_PORT` | DNS bind port | `53` |
| `FALLBACK` | Non-DNS UDP fallback endpoint | empty |
| `MAX_CONNECTIONS` | Max QUIC connections | `256` |
| `IDLE_TIMEOUT_SECONDS` | Idle timeout | `60` |
| `EXTRA_ARGS` | Extra raw CLI flags | empty |
| `RUST_LOG` | Log level | `info` |

TLS cert/key and the stateless-reset seed are stored in the `slipstream-data`
volume under `/data`. If the cert/key are missing the server auto-generates a
self-signed ECDSA P-256 certificate on first start.

## Networking notes

- The compose file uses `network_mode: host` so the tunnel can bind `53/udp`
  directly and reach a target on the host's `127.0.0.1`.
- Port `53/udp` is often held by `systemd-resolved`. Free it first, e.g.:

  ```bash
  sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
  sudo systemctl restart systemd-resolved
  ```

  Or run the tunnel on a different port with `--port` and forward `53` to it
  at the firewall.
- For a public server on `53/udp`, tune conntrack as described in the top-level
  `README.md` (Production note).

## What runs where

The container packages the upstream `slipstream-server` unchanged; no protocol
or core code is modified. See `docs/usage.md` for the full server CLI and
`docs/config.md` for tuning knobs.
