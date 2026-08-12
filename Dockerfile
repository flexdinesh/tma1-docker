# syntax=docker/dockerfile:1.7

ARG TMA1_VERSION=v0.2.0-alpha13
ARG GREPTIMEDB_VERSION=v1.1.3

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS tma1-builder

ARG TARGETARCH
ARG TMA1_VERSION

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates curl tar && \
  rm -rf /var/lib/apt/lists/*

# Download the same prebuilt binary and checksum used by install.sh. The
# release binary already embeds the dashboard and adapter resources, so the
# application source tree is not part of this image build.
RUN set -eux; \
  case "$TARGETARCH" in \
  amd64|arm64) tma1_arch="$TARGETARCH" ;; \
  *) echo "unsupported target architecture: $TARGETARCH" >&2; exit 1 ;; \
  esac; \
  asset="tma1-server-linux-${tma1_arch}.tar.gz"; \
  checksum_asset="${asset}.sha256sum"; \
  release_url="https://github.com/tma1-ai/tma1/releases/download/${TMA1_VERSION}"; \
  cd /tmp; \
  curl -fsSLO "${release_url}/${asset}"; \
  curl -fsSLO "${release_url}/${checksum_asset}"; \
  sha256sum -c "$checksum_asset"; \
  mkdir -p /out; \
  tar -xzf "$asset" -C /out; \
  test -f /out/tma1-server; \
  chmod 0755 /out/tma1-server

FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS greptime-builder

ARG TARGETARCH
ARG GREPTIMEDB_VERSION

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates curl findutils && \
  rm -rf /var/lib/apt/lists/*

# GreptimeDB publishes one Linux archive per supported architecture and a
# companion file containing the archive's SHA-256 digest.
RUN set -eux; \
  case "$TARGETARCH" in \
  amd64|arm64) greptime_arch="$TARGETARCH" ;; \
  *) echo "unsupported target architecture: $TARGETARCH" >&2; exit 1 ;; \
  esac; \
  asset="greptime-linux-${greptime_arch}-${GREPTIMEDB_VERSION}.tar.gz"; \
  release_url="https://github.com/GreptimeTeam/greptimedb/releases/download/${GREPTIMEDB_VERSION}"; \
  cd /tmp; \
  curl -fsSLO "${release_url}/${asset}"; \
  checksum_asset="greptime-linux-${greptime_arch}-${GREPTIMEDB_VERSION}.sha256sum"; \
  curl -fsSLO "${release_url}/${checksum_asset}"; \
  expected_sha="$(tr -d '[:space:]' < "$checksum_asset")"; \
  printf '%s  %s\n' "$expected_sha" "$asset" | sha256sum -c -; \
  mkdir -p /tmp/greptime-extract /out; \
  tar -xzf "$asset" -C /tmp/greptime-extract; \
  greptime_bin="$(find /tmp/greptime-extract -type f -name greptime -print -quit)"; \
  test -n "$greptime_bin"; \
  install -m 0755 "$greptime_bin" /out/greptime

FROM debian:bookworm-slim AS runtime

ARG GREPTIMEDB_VERSION

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates curl && \
  rm -rf /var/lib/apt/lists/* && \
  groupadd --gid 10001 tma1 && \
  useradd --uid 10001 --gid 10001 --create-home \
  --home-dir /home/tma1 --shell /usr/sbin/nologin tma1 && \
  install -d -o tma1 -g tma1 /var/lib/tma1

COPY --from=tma1-builder --chmod=0755 /out/tma1-server /usr/local/bin/tma1-server
COPY --from=greptime-builder --chmod=0755 /out/greptime /usr/local/lib/tma1/greptime
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV HOME=/home/tma1 \
  TMA1_HOST=0.0.0.0 \
  TMA1_PORT=14318 \
  TMA1_DATA_DIR=/var/lib/tma1 \
  TMA1_GREPTIMEDB_VERSION=${GREPTIMEDB_VERSION}

USER 10001:10001
WORKDIR /home/tma1

EXPOSE 14318

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["tma1-server"]
