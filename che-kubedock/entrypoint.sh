#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

# Docker API on :2475, containers run as pods in the workspace namespace
# (in-cluster config; the workspace ServiceAccount must be able to manage pods).
# --reverse-proxy relays published ports through kubedock itself, which needs
# no port-forward RBAC.
# shellcheck disable=SC2086
exec kubedock server \
  --listen-addr "${KUBEDOCK_LISTEN_ADDR}" \
  --reverse-proxy \
  ${KUBEDOCK_EXTRA_ARGS:-}
