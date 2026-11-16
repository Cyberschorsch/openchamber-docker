# openchamber-image

Docker image bundling [OpenChamber](https://github.com/openchamber/openchamber) and [OpenCode](https://opencode.ai), built for the Unraid template.

## How updates work

A GitHub Action runs daily:

1. Reads the latest `@openchamber/web` and `@opencode/cli` versions from npm.
2. Skips if that pair is already published.
3. Builds the image and runs `smoke-test.sh`: OpenCode version matches, `/health` answers, an OpenChamber reports OpenCode ready via `/health` and stays ready, the logs contain no known startup errors, and `gh`, `glab`, the git credential helper and the git identity work.
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
| `GH_TOKEN` | – | GitHub token, used by `git` over HTTPS and by `gh` (`GITHUB_TOKEN` works too) |
| `GITLAB_TOKEN` | – | GitLab token, used by `git` over HTTPS and by `glab` |
| `GITLAB_HOST` | `gitlab.com` | Only for a self-hosted GitLab |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | – | Identity for the agent's commits |

## Git access

The image ships `git`, `gh` and `glab`. Clone over HTTPS into `/home/agent/workspaces`; a credential helper (`git-credential-env`) hands the matching token to git for `github.com` and for the GitLab host, and to no other host. Tokens are read from the environment at runtime and are never written to disk, so nothing needs a volume. The identity is written to `/etc/gitconfig` at every start; a repository's own `user.name` / `user.email` still takes precedence.

The agent can do whatever the token can, so keep it narrow:

- GitHub: fine-grained token limited to the repositories you need, with `Contents` and `Pull requests` read/write, and an expiry date.
- GitLab: `read_repository` and `write_repository`; add `api` only if the agent should open merge requests.
- Protect `main` on both sides, so the agent pushes branches and you merge.

In the Unraid template, add the tokens as masked variables.

### Cloning a project

With the tokens set, start a new chat without a project and ask the agent to clone:

```
Clone https://github.com/owner/repo.git to /home/agent/workspaces/
```

The repository lands in `/home/agent/workspaces`; add it to OpenChamber with the **+** next to **Projects**.

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

If port 3000 is taken locally, set `SMOKE_PORT`, for example `SMOKE_PORT=3987 ./smoke-test.sh openchamber:test 2.1.3`.
