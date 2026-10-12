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

## Agent-friendly outputs

The site publishes a Markdown rendition of every page and an `llms.txt` index so that AI coding agents, and the [AFDocs](https://afdocs.dev) checks behind CLOMonitor's *agent readiness* section, can read the documentation without scraping HTML.

| Piece | Where |
|-------|-------|
| `markdown` and `llms` output formats | `config/_default/hugo.yaml` (`outputFormats`, `outputs`) |
| Markdown page templates | `layouts/_default/single.markdown.md`, `layouts/_default/list.markdown.md`, `layouts/partials/markdown/` |
| Markdown variants of Docsy shortcodes | `layouts/shortcodes/*.markdown.md` (`tabpane`, `tab`, `alert`, `pageinfo`) |
| `/llms.txt` | `layouts/index.llms.txt`, `layouts/partials/llms/entries.llms.txt` |
| Hidden pointer to `llms.txt` at the top of every HTML page | `layouts/partials/capsule/llms-directive.html`, rendered by the `baseof.html` copies in `layouts/docs/`, `layouts/_default/` and `layouts/single/` (Docsy 0.11 has no body-start hook) |
| `.md` URLs and `Accept: text/markdown` negotiation | `netlify/edge-functions/markdown.ts` plus the `Vary` header rules in `netlify.toml` (Netlify only) |
| CLOMonitor target URL | `.clomonitor.yml` |

Every page is written as `index.md` next to its `index.html`, so `hugo server` serves `/llms.txt` and `/docs/overview/index.md` locally. The `/docs/overview.md` rewrite and the `Accept: text/markdown` negotiation only exist on Netlify. Shortcodes without a `.markdown.md` variant fall back to their HTML template, so their output appears as HTML fragments inside the Markdown.
