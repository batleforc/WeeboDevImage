#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

# NO_START=true parks kubedock at boot to keep the sidecar light at rest;
# `sidecar-app start|stop|status` (inside this container) toggles it later.
APP_FLAG=/tmp/.sidecar-app-start
APP_PIDFILE=/tmp/.sidecar-app.pid
[ "${NO_START}" != "true" ] && touch "${APP_FLAG}"
[ -e "${APP_FLAG}" ] || echo "NO_START=true: kubedock parked, run 'sidecar-app start' to launch it"

# Docker API on :2475, containers run as pods in the workspace namespace
# (in-cluster config; the workspace ServiceAccount must be able to manage pods).
# --reverse-proxy relays published ports through kubedock itself, which needs
# no port-forward RBAC.
# setsid: the service gets its own session/process group so sidecar-app can
# group-kill it without touching the entrypoint
while true; do
  if [ ! -e "${APP_FLAG}" ]; then sleep 2; continue; fi
  # shellcheck disable=SC2086
  setsid kubedock server \
    --listen-addr "${KUBEDOCK_LISTEN_ADDR}" \
    --reverse-proxy \
    ${KUBEDOCK_EXTRA_ARGS:-} &
  echo $! > "${APP_PIDFILE}"
  wait $!
  rc=$?
  rm -f "${APP_PIDFILE}"
  if [ -e "${APP_FLAG}" ]; then
    echo "kubedock exited (rc=${rc}), restarting in 2s" >&2
    sleep 2
  else
    echo "kubedock parked via sidecar-app stop" >&2
  fi
done
