#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

# rustfs aborts on a missing volume root instead of creating it
mkdir -p "${RUSTFS_VOLUMES}"

# NO_START=true parks rustfs at boot to keep the sidecar light at rest;
# `sidecar-app start|stop|status` (inside this container) toggles it later.
APP_FLAG=/tmp/.sidecar-app-start
APP_PIDFILE=/tmp/.sidecar-app.pid
[ "${NO_START}" != "true" ] && touch "${APP_FLAG}"
[ -e "${APP_FLAG}" ] || echo "NO_START=true: rustfs parked, run 'sidecar-app start' to launch it"

# S3 API on :9000, console on :9001; config via RUSTFS_* env vars
# setsid: the service gets its own session/process group so sidecar-app can
# group-kill it without touching the entrypoint
while true; do
  if [ ! -e "${APP_FLAG}" ]; then sleep 2; continue; fi
  setsid rustfs "${RUSTFS_VOLUMES}" &
  echo $! > "${APP_PIDFILE}"
  wait $!
  rc=$?
  rm -f "${APP_PIDFILE}"
  if [ -e "${APP_FLAG}" ]; then
    echo "rustfs exited (rc=${rc}), restarting in 2s" >&2
    sleep 2
  else
    echo "rustfs parked via sidecar-app stop" >&2
  fi
done
