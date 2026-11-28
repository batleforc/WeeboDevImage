#!/bin/bash
set -uo pipefail

# NO_START=true parks kubedock at boot to keep the sidecar light at rest;
# `sidecar-app start|stop|status` (inside this container) toggles it later.
APP_FLAG=/tmp/.sidecar-app-start
APP_PIDFILE=/tmp/.sidecar-app.pid
[ "${NO_START}" != "true" ] && touch "${APP_FLAG}"
[ -e "${APP_FLAG}" ] || echo "NO_START=true: kubedock parked, run 'sidecar-app start' to launch it"

# kubedock talks to the API with the user's token: the kubeconfig the Che
# dashboard writes into every workspace container once it is Running. Not the
# ServiceAccount token (it cannot create pods, and weebo-si's KubeArmor policy
# blocks it). The dashboard rewrites the file with a fresh token on each start
# from it; client-go never rereads an inline token, so a changed file restarts
# kubedock (its running containers go with it).
KCFG="${KUBECONFIG:-${HOME}/.kube/config}"
# The dashboard points it at the ServiceAccount's ca.crt, which weebo-si's
# KubeArmor policy blocks (it shares the token's timestamped directory).
# che-operator always merges the cluster CA (kube-root-ca.crt) into its CA
# bundle, mounted in every container: under /etc/pki/ca-trust by default,
# under /public-certs with disableWorkspaceCaBundleMount. /home/user is shared
# with the tools container, so its kubectl gets the fix too.
SA_CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
fix_ca() {
  local ca
  for ca in /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /public-certs/tls-ca-bundle.pem; do
    [ -r "${ca}" ] || continue
    grep -qs "certificate-authority: ${SA_CA}" "${KCFG}" &&
      sed -i "s|certificate-authority: ${SA_CA}|certificate-authority: ${ca}|" "${KCFG}"
    return
  done
}
(
  last=""
  while sleep 5; do
    fix_ca
    cur=$(cksum < "${KCFG}" 2>/dev/null) || continue
    if [ -n "${last}" ] && [ "${cur}" != "${last}" ] && [ -s "${APP_PIDFILE}" ]; then
      echo "kubeconfig changed, restarting kubedock" >&2
      kill -TERM -- "-$(cat "${APP_PIDFILE}")" 2>/dev/null
    fi
    last=${cur}
  done
) &

# Docker API on :2475, containers run as pods in the workspace namespace.
# --reverse-proxy relays published ports through kubedock itself, which needs
# no port-forward RBAC.
# setsid: the service gets its own session/process group so sidecar-app can
# group-kill it without touching the entrypoint
waiting=""
while true; do
  if [ ! -e "${APP_FLAG}" ]; then sleep 2; continue; fi
  if [ ! -s "${KCFG}" ]; then
    [ -n "${waiting}" ] || { echo "waiting for the dashboard to inject ${KCFG}" >&2; waiting=1; }
    sleep 2; continue
  fi
  waiting=""
  fix_ca
  # shellcheck disable=SC2086
  setsid kubedock server \
    --kubeconfig "${KCFG}" \
    --listen-addr "${KUBEDOCK_LISTEN_ADDR}" \
    --pod-template "${KUBEDOCK_POD_TEMPLATE}" \
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
