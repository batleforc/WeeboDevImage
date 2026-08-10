#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

mkdir -p "${CHROME_PROFILE_DIR}"

# Che's DevWorkspace operator injects DISPLAY=:0 into every workspace container
# (its ssh-askpass wrapper needs DISPLAY set), which would put all sidecars on
# the same display. Our Xvfb display is governed by XVFB_DISPLAY instead.
export DISPLAY="${XVFB_DISPLAY:-:99}"

# VNC password: honor $VNC_PASSWORD, otherwise generate one at boot
# (classic VNC auth only uses the first 8 chars)
VNC_PASSWORD="${VNC_PASSWORD:-$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c8)}"
x11vnc -storepasswd "${VNC_PASSWORD}" /tmp/vnc.pass >/dev/null 2>&1
# stored on the shared /projects so the tools container can read it directly;
# falls back to /tmp when there is no workspace mount (local podman run)
SIDECAR_DIR=/projects/.sidecar
mkdir -p "${SIDECAR_DIR}" 2>/dev/null || SIDECAR_DIR=/tmp
printf '%s\n' "${VNC_PASSWORD}" > "${SIDECAR_DIR}/vnc-password-browser.txt"
chmod 640 "${SIDECAR_DIR}/vnc-password-browser.txt"
echo "=============================================="
echo " noVNC password: ${VNC_PASSWORD}"
echo " (also stored in ${SIDECAR_DIR}/vnc-password-browser.txt)"
echo "=============================================="

Xvfb "${DISPLAY}" -screen 0 "${SCREEN_GEOMETRY}" -nolisten tcp &
for _ in $(seq 1 50); do
  [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ] && break
  sleep 0.2
done

x11vnc -display "${DISPLAY}" -rfbport "${VNC_PORT}" -listen 127.0.0.1 -rfbauth /tmp/vnc.pass -forever -shared -quiet &
websockify --web /usr/share/novnc "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" &
chromedriver --port=9515 --allowed-ips= --allowed-origins='*' &
nginx -c /etc/che-browser/nginx-cdp.conf -g 'daemon off;' &

# Chrome respawns if closed/crashed (a human can close it via noVNC).
# CDP stays on loopback:9229; nginx fronts it on 0.0.0.0:9222.
(
  while true; do
    google-chrome \
      --no-sandbox --disable-dev-shm-usage --disable-gpu \
      --no-first-run --no-default-browser-check \
      --user-data-dir="${CHROME_PROFILE_DIR}" \
      --remote-debugging-port=9229 \
      --remote-allow-origins='*' \
      --window-position=0,0 --window-size=1920,1040 \
      "${CHROME_START_URL}"
    echo "chrome exited (rc=$?), restarting in 1s" >&2
    sleep 1
  done
) &

# If any infra process dies, exit so Kubernetes restarts the container
wait -n
echo "a che-browser service exited, terminating container" >&2
exit 1
