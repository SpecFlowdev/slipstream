<div align="center">

<h1>⚡ Slipstream</h1>
<p><strong>高性能 DNS 隧道 · QUIC over DNS · Rust</strong></p>

[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-stable-orange?style=flat-square&logo=rust)](https://www.rust-lang.org)
[![Docker](https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white)](deploy/)
[![QUIC](https://img.shields.io/badge/QUIC-multipath-purple?style=flat-square)](docs/protocol.md)

<br/>

[安装](#-一键安装) · [功能](#-功能特性) · [配置](#-配置) · [性能测试](#-性能测试) · [文档](#-文档)

<br/>

🌐 &nbsp;[English](README.md) &nbsp;·&nbsp; [Русский](README.ru.md) &nbsp;·&nbsp; [فارسی](README.fa.md)

</div>

---

## 🚀 一键安装

在任意全新主机上部署完整的 `slipstream-server`——自动安装 Docker（如未安装）、构建镜像并启动隧道。**脚本会交互式询问您的域名：**

```bash
curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
  | sudo bash
```

就这些。脚本会提示输入隧道域名，随后服务器开始在 `53/udp` 上监听。

> 更多选项、手动 Compose 使用方式及网络注意事项（释放 `53/udp`、conntrack 调优），请参阅 [deploy/README.md](deploy/README.md)。

---

## ✨ 功能特性

- **DNS 封装** — 将 QUIC 数据包封装在 DNS TXT 查询/响应中，与正常 DNS 流量无异
- **QUIC 传输** — 通过 [picoquic](https://github.com/private-octopus/picoquic) 实现完整的多路径 QUIC，端到端加密
- **两种解析模式** — 递归模式（标准 DNS 解析器）或权威模式（自有 NS 记录，BBR 拥塞控制，速度提升 3–4 倍）
- **完全异步** — 基于 Tokio 构建，每条隧道可处理数百个并发流
- **自签名证书** — 首次启动时若无证书，自动生成 ECDSA P-256 证书
- **Shadowsocks 插件** — 兼容 SIP003（`SS_*` 环境变量），可直接用于任意 Shadowsocks 客户端
- **一键 Docker 部署** — 一条 `curl | bash` 命令即可启动服务器
- **多域名支持** — 单台服务器，逗号分隔多个隧道域名

---

## ⚙️ 配置

Docker 部署通过 `deploy/.env` 中的环境变量驱动：

| 变量 | 含义 | 默认值 |
|---|---|---|
| `DOMAIN` | 隧道域名（逗号分隔） | **必填** |
| `TARGET_ADDRESS` | 解密流量转发目标 | `127.0.0.1:5201` |
| `DNS_LISTEN_HOST` | DNS 监听地址 | `::` |
| `DNS_LISTEN_PORT` | DNS 监听端口 | `53` |
| `FALLBACK` | 非 DNS UDP 回退端点 | 空 |
| `MAX_CONNECTIONS` | 最大 QUIC 连接数 | `256` |
| `IDLE_TIMEOUT_SECONDS` | 空闲超时（秒） | `60` |
| `EXTRA_ARGS` | 额外原始 CLI 参数 | 空 |
| `RUST_LOG` | 日志级别 | `info` |

---

## 🏗️ 从源码构建

**前置条件：** Rust stable、cmake、pkg-config、OpenSSL 头文件

```bash
git clone --recurse-submodules https://github.com/specflowdev/slipstream
cd slipstream
cargo build -p slipstream-client -p slipstream-server
```

---

## 📈 性能测试

端到端完成时间（秒，越低越好），10 MiB 有效载荷，本地回环，5 次平均。

| 方案 | 上传均值 (s) | 下载均值 (s) |
|---|---:|---:|
| dnstt | 16.207 | 2.492 |
| slipstream (C) | 5.332 | 1.096 |
| **slipstream-rust** | **3.249** | **0.978** |
| **slipstream-rust（权威模式）** | **1.602** | **0.407** |

---

## 📚 文档

| 文档 | 说明 |
|---|---|
| [deploy/README.md](deploy/README.md) | Docker 部署、Compose、网络配置 |
| [docs/usage.md](docs/usage.md) | 完整 CLI 参考 |
| [docs/protocol.md](docs/protocol.md) | DNS 封装细节 |
| [docs/build.md](docs/build.md) | 构建前置条件、picoquic 配置 |
| [docs/interop.md](docs/interop.md) | 本地测试工具 |
| [docs/benchmarks.md](docs/benchmarks.md) | 基准测试方法 |
| [docs/design.md](docs/design.md) | 架构说明 |

---

## 许可证

Apache-2.0 — 详见 [LICENSE](LICENSE)。
