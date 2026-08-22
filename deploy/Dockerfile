# ---- Build stage -------------------------------------------------------------
# Builds slipstream-server with a statically linked OpenSSL so the runtime image
# stays small and portable. picoquic/picotls are built by the crate build script.
FROM rust:1-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        pkg-config \
        perl \
        make \
        g++ \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy the whole workspace (build context is the repo root). The picoquic
# submodule under vendor/picoquic must already be checked out in the context.
COPY . .

# Static OpenSSL keeps the runtime image free of libssl version coupling.
RUN cargo build --release -p slipstream-server --features openssl-vendored,picoquic-minimal-build

# ---- Runtime stage -----------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/target/release/slipstream-server /usr/local/bin/slipstream-server
COPY deploy/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Persisted state: TLS cert/key and the stateless-reset seed.
VOLUME ["/data"]

# DNS tunnel listens on 53/udp. Compose uses host networking by default so this
# is informational, but it documents the port for other run styles.
EXPOSE 53/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
