#!/usr/bin/env bash
#
# Build every released version of the docs for GitHub Pages:
#   $OUTPUT/       -> latest release (apex)
#   $OUTPUT/vX.Y/  -> each release/X.Y branch, pinned
# Per-version config is injected at build time, so release branches carry only
# content. Env overrides: BASE_URL, OUTPUT.
set -euo pipefail

BASE_URL="${BASE_URL:-https://projectcapsule.dev}"
BASE_URL="${BASE_URL%/}"
OUTPUT="${OUTPUT:-public}"
[[ "${OUTPUT}" == /* ]] || OUTPUT="$(pwd)/${OUTPUT}"
readonly BASE_URL OUTPUT

# Emit the version-selector dropdown list as YAML (newest first; latest tagged).
# Globals: versions, latest, BASE_URL.
dropdown_yaml() {
  local v label url
  for v in "${versions[@]}"; do
    label="v${v}"
    url="${BASE_URL}/v${v}/"
    if [[ "${v}" == "${latest}" ]]; then
      label="${label} (latest)"
      url="${BASE_URL}/"  # latest is served at the apex, not /vX.Y/
    fi
    printf -- '- version: %s\n  url: %s\n' "${label}" "${url}"
  done
}

# Build one version with the per-version config injected.
# Arguments: version (X.Y), baseURL, dest dir, archived (true|false).
# Globals: latest, VERSIONS_YAML.
build_one() {
  local version="$1" baseurl="$2" dest="$3" archived="$4"
  local menu wt
  menu="v${version}"
  [[ "${version}" == "${latest}" ]] && menu="${menu} (latest)"
  # Worktree under $RUNNER_TEMP, not /tmp: snap yq/dart-sass have a private /tmp
  wt="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/build-site.XXXXXX")"
  echo "==> building v${version} (archived=${archived})"
  git worktree add --force --detach "${wt}" \
    "origin/release/${version}" >/dev/null
  (
    cd "${wt}" || exit 1
    VERSION="v${version}" MENU="${menu}" ARCHIVED="${archived}" \
      LATEST_URL="${BASE_URL}/" yq -i '
        .version = strenv(VERSION)
      | .version_menu = strenv(MENU)
      | .archived_version = (strenv(ARCHIVED) == "true")
      | .url_latest_version = strenv(LATEST_URL)
      | .versions = (strenv(VERSIONS_YAML) | from_yaml)
    ' config/_default/params.yaml
    # Subpath builds: point the selector at each version's home.
    yq -i '.params.version_menu_pagelinks = false' config/_default/hugo.yaml
    npm ci --no-audit --no-fund >/dev/null 2>&1 \
      || npm install --no-audit --no-fund >/dev/null 2>&1 || true
    hugo --gc --minify --baseURL "${baseurl}" --destination "${dest}"
  )
  git worktree remove --force "${wt}"
}

main() {
  rm -rf "${OUTPUT}"
  mkdir -p "${OUTPUT}"

  # release/X.Y branches, newest first (ignores patch/preview branches).
  mapfile -t versions < <(
    git for-each-ref --format='%(refname:lstrip=-1)' \
      "refs/remotes/origin/release/" \
      | grep -E '^[0-9]+\.[0-9]+$' \
      | sort -rV)
  if [[ "${#versions[@]}" -eq 0 ]]; then
    echo "no release/X.Y branches found" >&2
    exit 1
  fi
  latest="${versions[0]}"

  VERSIONS_YAML="$(dropdown_yaml)"
  export VERSIONS_YAML

  local v archived
  for v in "${versions[@]}"; do
    archived=true
    [[ "${v}" == "${latest}" ]] && archived=false
    build_one "${v}" "${BASE_URL}/v${v}/" "${OUTPUT}/v${v}" "${archived}"
  done
  build_one "${latest}" "${BASE_URL}/" "${OUTPUT}" false

  echo "==> done: ${versions[*]} (latest v${latest})"
}

main "$@"
