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

## Session artifacts

TMA1 can ingest local session artifacts from supported coding harnesses. Session access is opt-in: add one or more session override files to the architecture-specific Compose command.

| Harness | Compose override | Read-only artifact directory |
| --- | --- | --- |
| Claude Code | `compose.sessions.claude-code.yml` | `$HOME/.claude/projects` |
| Codex | `compose.sessions.codex.yml` | `$HOME/.codex/sessions` |
| Copilot CLI | `compose.sessions.copilot-cli.yml` | `$HOME/.copilot/session-state` |
| OpenClaw | `compose.sessions.openclaw.yml` | `$HOME/.openclaw/agents` |

Compose automatically uses your existing `HOME`. Before starting TMA1, provide the numeric identity that owns the artifacts:

```sh
export TMA1_RUNTIME_UID="$(id -u)"
export TMA1_RUNTIME_GID="$(id -g)"
```

For example, enable one source on ARM64:

```sh
docker compose \
  -f compose.arm64.yml \
  -f compose.sessions.codex.yml \
  up -d --build
```

Or combine sources on either architecture:

```sh
# ARM64
docker compose \
  -f compose.arm64.yml \
  -f compose.sessions.claude-code.yml \
  -f compose.sessions.codex.yml \
  -f compose.sessions.copilot-cli.yml \
  -f compose.sessions.openclaw.yml \
  up -d --build

# AMD64
docker compose \
  -f compose.amd64.yml \
  -f compose.sessions.claude-code.yml \
  -f compose.sessions.codex.yml \
  -f compose.sessions.copilot-cli.yml \
  -f compose.sessions.openclaw.yml \
  up -d --build
```

Use the same `-f` file list for later `config`, `up`, and `down` commands. For example:

```sh
docker compose \
  -f compose.arm64.yml \
  -f compose.sessions.codex.yml \
  down
```

Each selected artifact directory must already exist. Compose fails instead of creating an empty directory when a selected harness is not installed. The examples target macOS and Linux Docker hosts; Windows-native paths and identity mapping are outside the supported scope.

### Ingestion behavior

- Claude Code ingestion is hook-triggered. Its host-side TMA1 hook must already POST the absolute `transcript_path`; the override makes that same path readable in the container but does not install or rewrite the hook.
- Codex scans active session files from today and yesterday.
- Copilot CLI performs a historical first scan, then scans active sessions.
- OpenClaw scans recently active transcripts. Its current default location is `.openclaw`; legacy `.clawdbot` and custom OpenClaw state locations require manual advanced configuration.

Session directories are mounted read-only, but TMA1 reads conversation content from them and persists ingested data in its named database volume. Review the artifacts before opting in if they may contain sensitive information.

This feature does not mount project repositories, install MCP integrations or host hooks, or enable project, Git, and file sensors that require access to host repositories.
