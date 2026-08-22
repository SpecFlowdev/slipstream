<div align="right">

[English](README.md) · [中文](README.zh.md) · [Русский](README.ru.md) · [فارسی](README.fa.md)

</div>

<div align="center">

<h1>⚡ Slipstream</h1>
<p><strong>Высокопроизводительный DNS-туннель · QUIC over DNS · Rust</strong></p>

[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-stable-orange?style=flat-square&logo=rust)](https://www.rust-lang.org)
[![Docker](https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white)](deploy/)
[![QUIC](https://img.shields.io/badge/QUIC-multipath-purple?style=flat-square)](docs/protocol.md)

<br/>

[Установка](#-установка-одной-командой) · [Возможности](#-возможности) · [Конфигурация](#-конфигурация) · [Бенчмарки](#-бенчмарки) · [Документация](#-документация)

</div>

---

## 🚀 Установка одной командой

Разверните полноценный `slipstream-server` на любом чистом хосте — скрипт автоматически установит Docker (если его нет), соберёт образ и запустит туннель. **Домен спрашивается интерактивно:**

```bash
curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
  | sudo bash
```

Всё. Скрипт запросит домен туннеля, после чего сервер начнёт слушать на `53/udp`.

> Опции, ручное использование Compose и сетевые заметки (освобождение `53/udp`, настройка conntrack) — в [deploy/README.md](deploy/README.md).

---

## ✨ Возможности

- **DNS-инкапсуляция** — QUIC-пакеты передаются внутри DNS TXT-запросов/ответов; трафик неотличим от обычного DNS
- **QUIC-транспорт** — полноценный многопутевой QUIC через [picoquic](https://github.com/private-octopus/picoquic); сквозное шифрование
- **Два режима резолвера** — рекурсивный (стандартные DNS-резолверы) или авторитативный (собственная NS-запись, BBR CC, в 3–4 раза быстрее)
- **Полностью асинхронный** — построен на Tokio; каждый туннель обрабатывает сотни параллельных потоков
- **Самоподписанный сертификат** — при первом запуске автоматически генерируется сертификат ECDSA P-256
- **Плагин Shadowsocks** — совместим с SIP003 (переменные `SS_*`), работает как drop-in для любого клиента Shadowsocks
- **Развёртывание в Docker одной командой** — один `curl | bash` — и сервер готов
- **Несколько доменов** — один сервер, несколько туннельных доменов через запятую

---

## ⚙️ Конфигурация

Docker-деплой управляется переменными окружения из файла `deploy/.env`:

| Переменная | Описание | По умолчанию |
|---|---|---|
| `DOMAIN` | Домен(ы) туннеля, через запятую | **обязательно** |
| `TARGET_ADDRESS` | Куда пересылать расшифрованный трафик | `127.0.0.1:5201` |
| `DNS_LISTEN_HOST` | Адрес прослушивания DNS | `::` |
| `DNS_LISTEN_PORT` | Порт прослушивания DNS | `53` |
| `FALLBACK` | Запасной endpoint для не-DNS UDP | пусто |
| `MAX_CONNECTIONS` | Максимум QUIC-соединений | `256` |
| `IDLE_TIMEOUT_SECONDS` | Таймаут простоя (секунды) | `60` |
| `EXTRA_ARGS` | Дополнительные флаги CLI | пусто |
| `RUST_LOG` | Уровень логирования | `info` |

---

## 🏗️ Сборка из исходников

**Требования:** Rust stable, cmake, pkg-config, заголовочные файлы OpenSSL

```bash
git clone --recurse-submodules https://github.com/specflowdev/slipstream
cd slipstream
cargo build -p slipstream-client -p slipstream-server
```

---

## 📈 Бенчмарки

Время завершения от начала до конца (секунды, чем меньше — тем лучше), нагрузка 10 МиБ, локальный loopback, среднее из 5 запусков.

| Вариант | Загрузка avg (с) | Скачивание avg (с) |
|---|---:|---:|
| dnstt | 16.207 | 2.492 |
| slipstream (C) | 5.332 | 1.096 |
| **slipstream-rust** | **3.249** | **0.978** |
| **slipstream-rust (авторитативный)** | **1.602** | **0.407** |

---

## 📚 Документация

| Документ | Описание |
|---|---|
| [deploy/README.md](deploy/README.md) | Docker-деплой, Compose, сеть |
| [docs/usage.md](docs/usage.md) | Полный справочник CLI |
| [docs/protocol.md](docs/protocol.md) | Детали DNS-инкапсуляции |
| [docs/build.md](docs/build.md) | Требования для сборки, настройка picoquic |
| [docs/interop.md](docs/interop.md) | Локальные тест-стенды |
| [docs/benchmarks.md](docs/benchmarks.md) | Методология бенчмарков |
| [docs/design.md](docs/design.md) | Архитектурные заметки |

---

## Лицензия

Apache-2.0 — см. [LICENSE](LICENSE).
