#!/usr/bin/env bash
# Mirror CI: Hugo serves /static as /, so lychee needs images copied into content/
set -euo pipefail

had_images_dir=false
if [[ -d content/en/images ]]; then
  had_images_dir=true
else
  mkdir -p content/en/images
fi

cleanup() {
  if [[ "$had_images_dir" == false ]]; then
    rm -rf content/en/images
  fi
}
trap cleanup EXIT

cp -R static/images/. content/en/images/

lychee "$@"
