#!/usr/bin/env bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

# NO_START=true parks the LGTM stack at boot to keep the sidecar light at
# rest; `sidecar-app start|stop|status` (inside this container) toggles it.
APP_FLAG=/tmp/.sidecar-app-start
APP_PIDFILE=/tmp/.sidecar-app.pid
[ "${NO_START:-false}" != "true" ] && touch "${APP_FLAG}"
[ -e "${APP_FLAG}" ] || echo "NO_START=true: LGTM stack parked, run 'sidecar-app start' to launch it"

# upstream launcher: grafana + prometheus + tempo + loki + pyroscope + otelcol
# setsid: run-all.sh gets its own session/process group so sidecar-app can
# group-kill the whole stack it spawns (fallback: plain kill of the launcher
# if the base image has no setsid)
while true; do
  if [ ! -e "${APP_FLAG}" ]; then sleep 2; continue; fi
  if command -v setsid >/dev/null 2>&1; then
    setsid /otel-lgtm/run-all.sh &
  else
    /otel-lgtm/run-all.sh &
  fi
  echo $! > "${APP_PIDFILE}"
  wait $!
  rc=$?
  rm -f "${APP_PIDFILE}"
  if [ -e "${APP_FLAG}" ]; then
    echo "LGTM stack exited (rc=${rc}), restarting in 2s" >&2
    sleep 2
  else
    echo "LGTM stack parked via sidecar-app stop" >&2
  fi
done
