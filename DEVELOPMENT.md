# Development

## Pre-commit Hooks

This repository uses [prek](https://prek.j178.dev/) to run pre-commit hooks locally. `prek` is a fast, Rust-native drop-in replacement for [pre-commit](https://pre-commit.com/).

### Installation

Install `prek` via Homebrew:

```bash
brew install prek lychee
```

For other installation options, see the [prek installation docs](https://prek.j178.dev/installation/).

### Setup

After cloning the repository, install the Git shims so hooks run automatically:

```bash
prek install              # runs hooks on every commit
prek install --hook-type pre-push  # runs lychee link checker on every push
```

### Running Hooks Manually

Run all hooks against staged files:

```bash
prek run
```

Run all hooks against the entire repository:

```bash
prek run --all-files
```

Run a specific hook by ID:

```bash
prek run trailing-whitespace
```

Run only the link checker:

```bash
prek run --hook-stage pre-push lychee
```

Run only the API docs check:

```bash
prek run --hook-stage pre-push apidocs-check
```

### Configured Hooks

| Hook | Stage | Description |
|------|-------|-------------|
| `check-executables-have-shebangs` | commit | Ensures executable files have a shebang line |
| `end-of-file-fixer` | commit | Ensures files end with a newline |
| `trailing-whitespace` | commit | Removes trailing whitespace |
| `check-yaml` | commit | Validates YAML syntax |
| `check-merge-conflict` | commit | Detects leftover merge conflict markers |
| `yamllint` | commit | Lints YAML files for style issues |
| `lychee` | push | Checks for broken links in `content/` |
| `apidocs-check` | push | Regenerates API docs and fails if they are out of date |

All commit-stage hooks run only against files under `content/`.

### Updating Hook Versions

To update pinned hook repository revisions:

```bash
prek auto-update
```
