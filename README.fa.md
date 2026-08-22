<div align="center">

[English](README.md) · [中文](README.zh.md) · [Русский](README.ru.md) · [فارسی](README.fa.md)

</div>

<div align="center">

<h1>⚡ Slipstream</h1>
<p><strong>تونل DNS با کارایی بالا · QUIC over DNS · Rust</strong></p>

[![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-stable-orange?style=flat-square&logo=rust)](https://www.rust-lang.org)
[![Docker](https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white)](deploy/)
[![QUIC](https://img.shields.io/badge/QUIC-multipath-purple?style=flat-square)](docs/protocol.md)

<br/>

[نصب](#-نصب-با-یک-دستور) · [ویژگی‌ها](#-ویژگی‌ها) · [پیکربندی](#-پیکربندی) · [بنچمارک](#-بنچمارک) · [مستندات](#-مستندات)

</div>

---

<div dir="rtl">

## 🚀 نصب با یک دستور

`slipstream-server` را روی هر سرور تازه‌ای مستقر کنید — اسکریپت در صورت نیاز Docker را نصب می‌کند، ایمیج را می‌سازد و تونل را راه‌اندازی می‌کند. **دامنه به صورت تعاملی پرسیده می‌شود:**

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/specflowdev/slipstream/main/scripts/install.sh \
  | sudo bash
```

<div dir="rtl">

همین. اسکریپت دامنه تونل را می‌پرسد، سپس سرور روی `53/udp` شروع به گوش دادن می‌کند.

> برای گزینه‌ها، استفاده دستی از Compose و نکات شبکه (آزادسازی `53/udp`، تنظیم conntrack)، به [deploy/README.md](deploy/README.md) مراجعه کنید.

---

## ✨ ویژگی‌ها

- **کپسوله‌سازی DNS** — بسته‌های QUIC را در پرسش‌های DNS TXT جاسازی می‌کند؛ ترافیک از DNS معمولی قابل تشخیص نیست
- **انتقال QUIC** — QUIC چندمسیره کامل از طریق [picoquic](https://github.com/private-octopus/picoquic)؛ رمزگذاری سرتاسری
- **دو حالت resolver** — بازگشتی (DNS resolverهای استاندارد) یا اقتداری (NS record اختصاصی، BBR CC، تا ۴ برابر سریع‌تر)
- **کاملاً ناهمزمان** — بر پایه Tokio؛ هر تونل صدها جریان همزمان را مدیریت می‌کند
- **گواهی خودامضا** — در اولین اجرا، گواهی ECDSA P-256 به طور خودکار ایجاد می‌شود
- **پلاگین Shadowsocks** — سازگار با SIP003 (متغیرهای `SS_*`)؛ جایگزین مستقیم برای هر کلاینت Shadowsocks
- **استقرار Docker با یک دستور** — فقط یک `curl | bash` و سرور آماده است
- **چند دامنه** — یک سرور، چند دامنه تونل با ویرگول جدا شده

---

## ⚙️ پیکربندی

استقرار Docker از طریق متغیرهای محیطی در `deploy/.env` کنترل می‌شود:

| متغیر | معنا | پیش‌فرض |
|---|---|---|
| `DOMAIN` | دامنه(های) تونل، با ویرگول | **الزامی** |
| `TARGET_ADDRESS` | مقصد ارسال ترافیک رمزگشایی‌شده | `127.0.0.1:5201` |
| `DNS_LISTEN_HOST` | آدرس شنود DNS | `::` |
| `DNS_LISTEN_PORT` | پورت شنود DNS | `53` |
| `FALLBACK` | endpoint پشتیبان برای UDP غیر DNS | خالی |
| `MAX_CONNECTIONS` | حداکثر اتصالات QUIC | `256` |
| `IDLE_TIMEOUT_SECONDS` | وقفه بی‌کاری (ثانیه) | `60` |
| `EXTRA_ARGS` | آرگومان‌های اضافی CLI | خالی |
| `RUST_LOG` | سطح لاگ | `info` |

---

## 🏗️ ساخت از سورس

**پیش‌نیازها:** Rust stable، cmake، pkg-config، هدرهای OpenSSL

</div>

```bash
git clone --recurse-submodules https://github.com/specflowdev/slipstream
cd slipstream
cargo build -p slipstream-client -p slipstream-server
```

---

<div dir="rtl">

## 📈 بنچمارک

زمان تکمیل سرتاسری بر حسب ثانیه (هرچه کمتر بهتر)، بار ۱۰ مگابایت، loopback محلی، میانگین ۵ اجرا.

| روش | میانگین آپلود (ث) | میانگین دانلود (ث) |
|---|---:|---:|
| dnstt | 16.207 | 2.492 |
| slipstream (C) | 5.332 | 1.096 |
| **slipstream-rust** | **3.249** | **0.978** |
| **slipstream-rust (اقتداری)** | **1.602** | **0.407** |

---

## 📚 مستندات

| سند | توضیح |
|---|---|
| [deploy/README.md](deploy/README.md) | استقرار Docker، Compose، شبکه |
| [docs/usage.md](docs/usage.md) | راهنمای کامل CLI |
| [docs/protocol.md](docs/protocol.md) | جزئیات کپسوله‌سازی DNS |
| [docs/build.md](docs/build.md) | پیش‌نیازهای ساخت، راه‌اندازی picoquic |
| [docs/interop.md](docs/interop.md) | محیط‌های تست محلی |
| [docs/benchmarks.md](docs/benchmarks.md) | روش‌شناسی بنچمارک |
| [docs/design.md](docs/design.md) | معماری سیستم |

---

## مجوز

Apache-2.0 — به [LICENSE](LICENSE) مراجعه کنید.

</div>
