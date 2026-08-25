#!/usr/bin/env bash
# Regenerate API docs and fail if they are not up to date with the committed files.
set -euo pipefail

tmp_capsule="$(mktemp -d)"
tmp_proxy="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_capsule" "$tmp_proxy"
}
trap cleanup EXIT

make TARGET_DIR="$tmp_capsule" apidocs-capsule
make TARGET_DIR="$tmp_proxy" apidocs-capsule-proxy

if ! git diff --quiet -- content/en/docs/reference.md content/en/docs/proxy/reference.md; then
  echo ">>> API docs are out of date. Run 'make apidocs' and commit the result."
  git --no-pager diff -- content/en/docs/reference.md content/en/docs/proxy/reference.md
  exit 1
fi
