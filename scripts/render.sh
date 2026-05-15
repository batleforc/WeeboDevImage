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

REGISTRY="$(_yq '.registry')"
BASE_UBUNTU="$(_yq '.base.ubuntu')"
BASE_UBUNTU_REGISTRY="$(_yq '.base.ubuntu_registry // ""')"
if [[ -n "$BASE_UBUNTU_REGISTRY" ]]; then
  BASE_UBUNTU_IMAGE="${BASE_UBUNTU_REGISTRY}/ubuntu:${BASE_UBUNTU}"
else
  BASE_UBUNTU_IMAGE="ubuntu:${BASE_UBUNTU}"
fi
MIN_KUBECTL="$(_yq '.min.kubectl')"
MIN_NVM="$(_yq '.min.nvm')"
MIN_NODE="$(_yq '.min.node')"
BASE_TOOLS_HELM="$(_yq '.base_tools.helm')"
BASE_TOOLS_TASKFILE="$(_yq '.base_tools.taskfile')"
BASE_TOOLS_K9S="$(_yq '.base_tools.k9s')"
BASE_TOOLS_KREW="$(_yq '.base_tools.krew')"
BASE_TOOLS_GITLEAKS="$(_yq '.base_tools.gitleaks')"
BASE_TOOLS_KUBEDOCK="$(_yq '.base_tools.kubedock')"
BASE_TOOLS_BUILDKIT="$(_yq '.base_tools.buildkit')"
BASE_TOOLS_COCOGITTO="$(_yq '.base_tools.cocogitto')"
BASE_TOOLS_YQ="$(_yq '.base_tools.yq')"
BASE_TOOLS_MISE="$(_yq '.base_tools.mise')"
GOLANG_VERSION="$(_yq '.golang.version')"
RUST_VERSION="$(_yq '.rust.version')"
RUSTUP_VERSION="$(_yq '.rustup.version')"
RUSTUP_SHA256_AMD64="$(_yq '.rustup.sha256.amd64')"
RUSTUP_SHA256_ARMHF="$(_yq '.rustup.sha256.armhf')"
RUSTUP_SHA256_ARM64="$(_yq '.rustup.sha256.arm64')"
RUSTUP_SHA256_I386="$(_yq '.rustup.sha256.i386')"
RUSTUP_SHA256_PPC64EL="$(_yq '.rustup.sha256.ppc64el')"
RUSTUP_SHA256_S390X="$(_yq '.rustup.sha256.s390x')"
OPS_ARGOCD="$(_yq '.ops.argocd')"
OPS_CLUSTERCTL="$(_yq '.ops.clusterctl')"
OPS_TALOSCTL="$(_yq '.ops.talosctl')"
OPS_OPENTOFU="$(_yq '.ops.opentofu')"
OPS_UPDATECLI="$(_yq '.ops.updatecli')"

render_tpl() {
  local tpl="$1"
  sed \
    -e "s|@@REGISTRY@@|${REGISTRY}|g" \
    -e "s|@@BASE_UBUNTU_IMAGE@@|${BASE_UBUNTU_IMAGE}|g" \
    -e "s|@@BASE_UBUNTU@@|${BASE_UBUNTU}|g" \
    -e "s|@@MIN_KUBECTL@@|${MIN_KUBECTL}|g" \
    -e "s|@@MIN_NVM@@|${MIN_NVM}|g" \
    -e "s|@@MIN_NODE@@|${MIN_NODE}|g" \
    -e "s|@@BASE_TOOLS_HELM@@|${BASE_TOOLS_HELM}|g" \
    -e "s|@@BASE_TOOLS_TASKFILE@@|${BASE_TOOLS_TASKFILE}|g" \
    -e "s|@@BASE_TOOLS_K9S@@|${BASE_TOOLS_K9S}|g" \
    -e "s|@@BASE_TOOLS_KREW@@|${BASE_TOOLS_KREW}|g" \
    -e "s|@@BASE_TOOLS_GITLEAKS@@|${BASE_TOOLS_GITLEAKS}|g" \
    -e "s|@@BASE_TOOLS_KUBEDOCK@@|${BASE_TOOLS_KUBEDOCK}|g" \
    -e "s|@@BASE_TOOLS_BUILDKIT@@|${BASE_TOOLS_BUILDKIT}|g" \
    -e "s|@@BASE_TOOLS_COCOGITTO@@|${BASE_TOOLS_COCOGITTO}|g" \
    -e "s|@@BASE_TOOLS_YQ@@|${BASE_TOOLS_YQ}|g" \
    -e "s|@@BASE_TOOLS_MISE@@|${BASE_TOOLS_MISE}|g" \
    -e "s|@@GOLANG_VERSION@@|${GOLANG_VERSION}|g" \
    -e "s|@@RUST_VERSION@@|${RUST_VERSION}|g" \
    -e "s|@@RUSTUP_VERSION@@|${RUSTUP_VERSION}|g" \
    -e "s|@@RUSTUP_SHA256_AMD64@@|${RUSTUP_SHA256_AMD64}|g" \
    -e "s|@@RUSTUP_SHA256_ARMHF@@|${RUSTUP_SHA256_ARMHF}|g" \
    -e "s|@@RUSTUP_SHA256_ARM64@@|${RUSTUP_SHA256_ARM64}|g" \
    -e "s|@@RUSTUP_SHA256_I386@@|${RUSTUP_SHA256_I386}|g" \
    -e "s|@@RUSTUP_SHA256_PPC64EL@@|${RUSTUP_SHA256_PPC64EL}|g" \
    -e "s|@@RUSTUP_SHA256_S390X@@|${RUSTUP_SHA256_S390X}|g" \
    -e "s|@@OPS_ARGOCD@@|${OPS_ARGOCD}|g" \
    -e "s|@@OPS_CLUSTERCTL@@|${OPS_CLUSTERCTL}|g" \
    -e "s|@@OPS_TALOSCTL@@|${OPS_TALOSCTL}|g" \
    -e "s|@@OPS_OPENTOFU@@|${OPS_OPENTOFU}|g" \
    -e "s|@@OPS_UPDATECLI@@|${OPS_UPDATECLI}|g" \
    "${tpl}"
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
