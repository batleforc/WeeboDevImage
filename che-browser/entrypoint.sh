#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

mkdir -p "${CHROME_PROFILE_DIR}"

# VNC password: honor $VNC_PASSWORD, otherwise generate one at boot
# (classic VNC auth only uses the first 8 chars)
VNC_PASSWORD="${VNC_PASSWORD:-$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c8)}"
x11vnc -storepasswd "${VNC_PASSWORD}" /tmp/vnc.pass >/dev/null 2>&1
(umask 077 && printf '%s\n' "${VNC_PASSWORD}" > /tmp/vnc_password.txt)
echo "=============================================="
echo " noVNC password: ${VNC_PASSWORD}"
echo " (also stored in /tmp/vnc_password.txt)"
echo "=============================================="

Xvfb "${DISPLAY}" -screen 0 "${SCREEN_GEOMETRY}" -nolisten tcp &
for _ in $(seq 1 50); do
  [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ] && break
  sleep 0.2
done

x11vnc -display "${DISPLAY}" -rfbport 5900 -listen 127.0.0.1 -rfbauth /tmp/vnc.pass -forever -shared -quiet &
websockify --web /usr/share/novnc 0.0.0.0:6080 127.0.0.1:5900 &
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
