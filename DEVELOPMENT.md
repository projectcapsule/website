# Development

## Environment

Install [Devbox](https://www.jetify.com/docs/devbox/installing_devbox), then run:

```bash
devbox shell
task setup
```

Devbox provides the tools declared in `devbox.json`, with package resolutions
pinned in `devbox.lock`. `task setup` installs Node.js dependencies from
`package-lock.json` and both prek Git hooks. Run the commands below inside the
Devbox shell, or prefix them with `devbox run`, for example `devbox run task lychee`.

Hugo is pinned to 0.134.0 for compatibility with the current Docsy 0.11.0 theme.
Upgrade Hugo and Docsy together. CI uses the same tools and committed Go modules.

## Tasks

Run `task --list` to see the available tasks.

| Command | Description |
|---------|-------------|
| `task serve` | Start the Hugo development server at <http://localhost:1313> |
| `task build` | Build the production site into `public/` |
| `task lychee` | Check documentation links using the same configuration as CI |
| `task docs-lint` | Check documentation spelling |
| `task apidocs` | Regenerate Capsule and Capsule Proxy API docs |
| `task apidocs:capsule` | Regenerate only Capsule API docs |
| `task apidocs:proxy` | Regenerate only Capsule Proxy API docs |
| `task apidocs:check` | Compare generated API docs without changing source files |
| `task hooks:install` | Install the commit and push hooks |
| `task hooks` | Run commit hooks against all files |

The API docs tasks clone the upstream `main` branches by default and install the
pinned crdoc generator into `bin/` as needed. Override the upstream ref or URL
when necessary:

```bash
task apidocs:capsule REF=v0.12.0
task apidocs:proxy REPO_URL=https://github.com/projectcapsule/capsule-proxy.git REF=main
```

Pass extra command arguments after `--`:

```bash
task serve -- --bind 0.0.0.0
task lychee -- --offline
```

Outside the shell, keep Devbox's argument separator when forwarding flags:

```bash
devbox run -- task lychee -- --offline
```

Lychee uses `config/lychee.toml` for concurrency, retries, accepted status codes,
timeouts, and exclusions. Private addresses are excluded, matching CI. The
task temporarily copies static images into the content tree to resolve Hugo
image links and cleans them up afterward. Set `GITHUB_TOKEN` if needed for GitHub
link checks.

## Git hooks

This repository already uses [prek](https://prek.j178.dev/) with `prek.toml`.
`task setup` or `task hooks:install` installs both the `pre-commit` and `pre-push`
hooks. The push hooks invoke tasks through Devbox so their tools are available
outside an interactive Devbox shell.

Run hooks manually:

```bash
prek run                                      # staged files
task hooks                                    # all files, commit stage
prek run trailing-whitespace                   # one commit hook
prek run lychee                               # link check at commit stage
prek run --hook-stage pre-push lychee          # link check at push stage
prek run --hook-stage pre-push apidocs-check   # API docs check
```

| Hook | Stage | Description |
|------|-------|-------------|
| `check-executables-have-shebangs` | commit | Check executable shebangs |
| `end-of-file-fixer` | commit | Ensure files end with a newline |
| `trailing-whitespace` | commit | Remove trailing whitespace |
| `check-yaml` | commit | Validate YAML syntax |
| `check-merge-conflict` | commit | Detect merge conflict markers |
| `yamllint` | commit | Lint YAML style |
| `lychee` | commit, push | Check documentation links |
| `apidocs-check` | push | Check generated API docs |

Formatting and YAML hooks run only against `content/`, excluding the generated
API reference files. Lychee always runs its full check at both commit and push
stages. The API docs check runs at push time.

Update pinned hook repository revisions with:

```bash
prek update
```
