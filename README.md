# openchamber-image

Docker image bundling [OpenChamber](https://github.com/openchamber/openchamber) and [OpenCode](https://opencode.ai), built for the Unraid template.

## How updates work

A GitHub Action runs daily:

1. Reads the latest `@openchamber/web` and `@opencode/cli` versions from npm.
2. Skips if that pair is already published.
3. Builds the image and runs `smoke-test.sh`: OpenCode version matches, `/health` answers, an OpenChamber reports OpenCode ready via `/health` and stays ready, and the logs contain no known startup errors.
4. Only if the smoke test passes: pushes `latest`, `openchamber-<version>` and `openchamber-<version>-opencode-<version>` to GHCR and records the pair in `versions.json`.
5. If anything fails: nothing is pushed, `latest` stays on the last working build, and an issue labelled `build-failure` is opened (or commented on). The issue closes itself on the next successful build.

You only need to act when an issue appears.

## Tags

| Tag | Meaning |
|---|---|
| `latest` | Newest pair that passed the smoke test |
| `openchamber-1.21.1` | Newest tested build of that OpenChamber version |
| `openchamber-1.21.1-opencode-2.1.3` | Exact pair, for pinning |

## Environment

| Variable | Default | |
|---|---|---|
| `OPENCHAMBER_UI_PASSWORD` | – | Password for the web UI |
| `PUID` / `PGID` | `1000` / `1000` | Unraid: `99` / `100` |
| `SKIP_FIX_PERMISSIONS` | `false` | Skip the `chown` of config dirs at start |

## Volumes

| Path | Content |
|---|---|
| `/home/agent/workspaces` | Projects |
| `/home/agent/.config/opencode` | OpenCode config |
| `/home/agent/.local/share/opencode` | OpenCode sessions and provider logins |
| `/home/agent/.config/openchamber` | OpenChamber settings |

## Run the smoke test locally

```sh
docker build -t openchamber:test --build-arg OPENCODE_VERSION=2.1.3 .
./smoke-test.sh openchamber:test 2.1.3
```
