# TMA1 Docker

A minimal Docker distribution of [TMA1](https://github.com/tma1-ai/tma1) for Linux `amd64` and `arm64`.

This repository packages the release binaries used by the [TMA1 install script](https://tma1.ai/install.sh), including GreptimeDB, into a small Debian-based image. Downloads are checksum-verified, the container runs as a non-root user, and data is persisted in a named Docker volume.

## Run

Docker with Compose is required. Choose the file matching the target architecture:

```sh
# Apple Silicon and other ARM64 systems
docker compose -f compose.arm64.yml up -d --build

# Intel/AMD 64-bit systems
docker compose -f compose.amd64.yml up -d --build
```

Open the dashboard at [http://localhost:14318](http://localhost:14318).

To stop TMA1:

```sh
docker compose -f compose.arm64.yml down
# or
docker compose -f compose.amd64.yml down
```

The service is bound to localhost by default. TMA1 and GreptimeDB versions can be changed through the build arguments in the relevant Compose file.
