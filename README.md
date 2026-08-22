<div align="center">

<h1>⚡ Slipstream</h1>
<p><strong>High-performance DNS tunnel · QUIC over DNS · Rust</strong></p>

[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-stable-orange?style=flat-square&logo=rust)](https://www.rust-lang.org)
[![Docker](https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white)](deploy/)
[![QUIC](https://img.shields.io/badge/QUIC-multipath-purple?style=flat-square)](docs/protocol.md)

<br/>

[Install](#-one-command-install) · [Features](#-features) · [Configuration](#-configuration) · [Benchmarks](#-benchmarks) · [Docs](#-documentation)

<br/>

🌐 &nbsp;[中文](README.zh.md) &nbsp;·&nbsp; [Русский](README.ru.md) &nbsp;·&nbsp; [فارسی](README.fa.md)

</div>

---

## 🚀 One-command install

Deploy a full `slipstream-server` on any fresh host — installs Docker if missing, builds the image, and starts the tunnel. **The script will ask for your domain interactively:**

```bash
curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
  | sudo bash
```

That's it. The script prompts for your tunnel domain, then the server starts listening on `53/udp`.

> See [deploy/README.md](deploy/README.md) for options, manual Compose usage, and networking notes (freeing `53/udp`, conntrack tuning).

---

## ✨ Features

- **DNS encapsulation** — carries QUIC packets inside DNS TXT queries/responses; blends with normal DNS traffic
- **QUIC transport** — full multipath QUIC via [picoquic](https://github.com/private-octopus/picoquic); encrypted end-to-end
- **Two resolver modes** — recursive (standard DNS resolvers) or authoritative (own NS record, BBR CC, 3–4× faster)
- **Fully async** — built on Tokio; handles hundreds of concurrent streams per tunnel
- **Self-signed cert** — auto-generates an ECDSA P-256 cert on first start when none is provided
- **Shadowsocks plugin** — SIP003-compatible (`SS_*` env vars), drop-in for any Shadowsocks client
- **One-command Docker deploy** — single `curl | bash` to a running server
- **Comma-separated domains** — one server, multiple tunnel domains

---

## ⚙️ Configuration

The Docker deployment is driven by environment variables in `deploy/.env`:

| Variable | Meaning | Default |
|---|---|---|
| `DOMAIN` | Tunnel domain(s), comma-separated | **required** |
| `TARGET_ADDRESS` | Forward decrypted traffic here | `127.0.0.1:5201` |
| `DNS_LISTEN_HOST` | DNS bind host | `::` |
| `DNS_LISTEN_PORT` | DNS bind port | `53` |
| `FALLBACK` | Non-DNS UDP fallback endpoint | empty |
| `MAX_CONNECTIONS` | Max QUIC connections | `256` |
| `IDLE_TIMEOUT_SECONDS` | Idle timeout | `60` |
| `EXTRA_ARGS` | Extra raw CLI flags | empty |
| `RUST_LOG` | Log level | `info` |

---

## 🏗️ Build from source

**Prerequisites:** Rust stable, cmake, pkg-config, OpenSSL headers

```bash
git clone --recurse-submodules https://github.com/specflowdev/slipstream
cd slipstream
cargo build -p slipstream-client -p slipstream-server
```

---

## 📈 Benchmarks

End-to-end completion times in seconds (lower is better), 10 MiB payload, local loopback, averaged over 5 runs.

| Variant | Exfil avg (s) | Download avg (s) |
|---|---:|---:|
| dnstt | 16.207 | 2.492 |
| slipstream (C) | 5.332 | 1.096 |
| **slipstream-rust** | **3.249** | **0.978** |
| **slipstream-rust (Authoritative)** | **1.602** | **0.407** |

---

## 📚 Documentation

| Doc | Description |
|---|---|
| [deploy/README.md](deploy/README.md) | Docker deployment, Compose, networking |
| [docs/usage.md](docs/usage.md) | Full CLI reference |
| [docs/protocol.md](docs/protocol.md) | DNS encapsulation details |
| [docs/build.md](docs/build.md) | Build prerequisites, picoquic setup |
| [docs/interop.md](docs/interop.md) | Local test harnesses |
| [docs/benchmarks.md](docs/benchmarks.md) | Benchmark methodology |
| [docs/design.md](docs/design.md) | Architecture notes |

---

## 🗂️ Repo layout

```
crates/     Rust workspace crates
deploy/     Docker deployment (Dockerfile, Compose, entrypoint)
docs/       Documentation
fixtures/   Golden DNS codec test vectors
scripts/    Install, interop, and benchmark harnesses
vendor/     picoquic submodule
```

---

## License

Apache-2.0 — see [LICENSE](LICENSE).
