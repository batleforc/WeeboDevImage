#!/usr/bin/env bash
# Renders each */Containerfile.tpl -> Containerfile by substituting @@VAR@@ markers
# from versions.yaml. Run: task render  or  bash scripts/render.sh
# Use --check to verify no drift without writing files (used by CI).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
V="${REPO_ROOT}/versions.yaml"
BANNER="# GENERATED FILE — do not edit directly. Edit Containerfile.tpl + versions.yaml, then run: task render"

CHECK_MODE=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=true
fi

if ! command -v yq &>/dev/null; then
  echo "ERROR: yq is required. Install it or run inside the dev container." >&2
  exit 1
fi

_yq() { yq e "$1" "$V"; }

# BASE_UBUNTU_IMAGE is computed, not a direct yaml leaf
BASE_UBUNTU="$(_yq '.base.ubuntu')"
BASE_UBUNTU_REGISTRY="$(_yq '.base.ubuntu_registry // ""')"
if [[ -n "$BASE_UBUNTU_REGISTRY" ]]; then
  BASE_UBUNTU_IMAGE="${BASE_UBUNTU_REGISTRY}/ubuntu:${BASE_UBUNTU}"
else
  BASE_UBUNTU_IMAGE="ubuntu:${BASE_UBUNTU}"
fi

render_tpl() {
  local tpl="$1"
  local sed_args=(-e "s|@@BASE_UBUNTU_IMAGE@@|${BASE_UBUNTU_IMAGE}|g")
  local line key value var_name escaped_value

  # Flatten all yaml leaves (dot.separated.path = value) and build sed args dynamically.
  # Adding a new key to versions.yaml automatically makes @@KEY@@ available in templates.
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%% = *}"
    value="${line#* = }"
    var_name="$(printf '%s' "${key}" | tr '[:lower:].' '[:upper:]_')"
    escaped_value="${value//\\/\\\\}"
    escaped_value="${escaped_value//|/\\|}"
    sed_args+=(-e "s|@@${var_name}@@|${escaped_value}|g")
  done < <(yq e '.' -o=props "$V")

  sed "${sed_args[@]}" "${tpl}"
}

FAILED=0

for tpl in "${REPO_ROOT}"/*/Containerfile.tpl; do
  dir="$(dirname "${tpl}")"
  image_name="$(basename "${dir}")"
  target="${dir}/Containerfile"

  if $CHECK_MODE; then
    tmp="$(mktemp)"
    { printf '%s\n' "${BANNER}"; render_tpl "${tpl}"; } > "${tmp}"
    if ! diff -q "${target}" "${tmp}" > /dev/null 2>&1; then
      echo "DRIFT: ${image_name}/Containerfile is out of date with its template"
      diff "${target}" "${tmp}" || true
      FAILED=1
    fi
    rm -f "${tmp}"
  else
    { printf '%s\n' "${BANNER}"; render_tpl "${tpl}"; } > "${target}"
    echo "Rendered: ${image_name}/Containerfile"
  fi
done

if $CHECK_MODE; then
  if [[ $FAILED -ne 0 ]]; then
    echo "Some Containerfiles are out of date. Run: task render" >&2
    exit 1
  fi
  echo "All Containerfiles are up to date."
fi

FAILED=0

for tpl in "${REPO_ROOT}"/devfile.yaml.tpl "${REPO_ROOT}"/*/devfile.yaml.tpl; do
  [[ -f "$tpl" ]] || continue
  dir="$(dirname "${tpl}")"
  target="${dir}/devfile.yaml"

  if $CHECK_MODE; then
    tmp="$(mktemp)"
    render_tpl "${tpl}" > "${tmp}"
    if ! diff -q "${target}" "${tmp}" > /dev/null 2>&1; then
      echo "DRIFT: ${tpl} is out of date"
      diff "${target}" "${tmp}" || true
      FAILED=1
    fi
    rm -f "${tmp}"
  else
    render_tpl "${tpl}" > "${target}"
    echo "Rendered: ${target#"${REPO_ROOT}/"}"
  fi
done

if $CHECK_MODE; then
  if [[ $FAILED -ne 0 ]]; then
    echo "Some devfiles are out of date. Run: task render" >&2
    exit 1
  fi
  echo "All devfiles are up to date."
fi
