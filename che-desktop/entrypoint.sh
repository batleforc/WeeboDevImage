#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

mkdir -p "${XDG_RUNTIME_DIR}" && chmod 700 "${XDG_RUNTIME_DIR}"

# VNC password: honor $VNC_PASSWORD, otherwise generate one at boot
# (classic VNC auth only uses the first 8 chars)
VNC_PASSWORD="${VNC_PASSWORD:-$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c8)}"
x11vnc -storepasswd "${VNC_PASSWORD}" /tmp/vnc.pass >/dev/null 2>&1
# stored on the shared /projects so the tools container can read it directly;
# falls back to /tmp when there is no workspace mount (local podman run)
SIDECAR_DIR=/projects/.sidecar
mkdir -p "${SIDECAR_DIR}" 2>/dev/null || SIDECAR_DIR=/tmp
printf '%s\n' "${VNC_PASSWORD}" > "${SIDECAR_DIR}/vnc-password-desktop.txt"
chmod 640 "${SIDECAR_DIR}/vnc-password-desktop.txt"
echo "=============================================="
echo " noVNC password: ${VNC_PASSWORD}"
echo " (also stored in ${SIDECAR_DIR}/vnc-password-desktop.txt)"
echo "=============================================="

Xvfb "${DISPLAY}" -screen 0 "${SCREEN_GEOMETRY}" -nolisten tcp &
for _ in $(seq 1 50); do
  [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ] && break
  sleep 0.2
done

x11vnc -display "${DISPLAY}" -rfbport "${VNC_PORT}" -listen 127.0.0.1 -rfbauth /tmp/vnc.pass -forever -shared -quiet &
websockify --web /usr/share/novnc "0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" &

# Session bus: GTK/Electron/Tauri apps expect one. dbus-launch daemonizes, so
# it is deliberately outside the wait -n watchdog.
eval "$(dbus-launch --sh-syntax)"

openbox &

# App under test respawns if it exits (a human can close it via noVNC to pick
# up a rebuilt binary from /projects). Without DESKTOP_APP_CMD, a respawning
# xterm keeps the display usable for launching things by hand.
(
  cd "${DESKTOP_APP_CWD}" 2>/dev/null || cd "${HOME}"
  while true; do
    if [ -n "${DESKTOP_APP_CMD}" ]; then
      bash -c "${DESKTOP_APP_CMD}"
      echo "desktop app exited (rc=$?), restarting in ${DESKTOP_APP_RESTART_DELAY}s" >&2
    else
      xterm -geometry 120x30+40+40 -title "che-desktop — set DESKTOP_APP_CMD or launch your app here"
      echo "xterm exited (rc=$?), restarting in ${DESKTOP_APP_RESTART_DELAY}s" >&2
    fi
    sleep "${DESKTOP_APP_RESTART_DELAY}"
  done
) &

# If any infra process dies (Xvfb, x11vnc, websockify, openbox), exit so Kubernetes restarts the container
wait -n
echo "a che-desktop service exited, terminating container" >&2
exit 1
