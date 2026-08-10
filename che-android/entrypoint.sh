#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

mkdir -p "${ANDROID_AVD_HOME}"

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

# AVD is created at boot so it lands in the GID-0-writable home; -no-snapshot
# means every start is a cold boot, so there is nothing to warm up at build time
if [ ! -d "${ANDROID_AVD_HOME}/${AVD_NAME}.avd" ]; then
  echo "no" | avdmanager create avd --force \
    --name "${AVD_NAME}" \
    --package "system-images;android-${ANDROID_API};google_apis;x86_64" \
    --device "${AVD_DEVICE}"
  {
    echo "hw.lcd.width=${LCD_WIDTH}"
    echo "hw.lcd.height=${LCD_HEIGHT}"
    echo "hw.lcd.density=${LCD_DENSITY}"
    echo "hw.keyboard=yes"
    echo "hw.audioInput=no"
    echo "hw.audioOutput=no"
    echo "hw.ramSize=${EMULATOR_RAM_MB}"
    echo "disk.dataPartition.size=${EMULATOR_PARTITION_MB}M"
  } >> "${ANDROID_AVD_HOME}/${AVD_NAME}.avd/config.ini"
fi

# adb server on loopback:5037 — the tools container reaches it through the shared
# pod network namespace (ADB_SERVER_SOCKET=tcp:localhost:5037); no route needed
adb server nodaemon &

appium server --address 0.0.0.0 --port 4723 --allow-cors --relaxed-security &

# Emulator respawns if it exits (a human can close its window via noVNC).
# CPU-only: -accel off (QEMU TCG, no /dev/kvm) + swiftshader GPU; expect a
# multi-minute cold boot. The boot watcher lives INSIDE this subshell so the
# top-level `wait -n` never sees it exit.
(
  while true; do
    (
      adb wait-for-device 2>/dev/null
      start=${SECONDS}
      until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
        echo "android: still booting (software emulation is slow, $((SECONDS - start))s elapsed)"
        sleep 15
      done
      echo "=============================================="
      echo " android: boot completed in $((SECONDS - start))s"
      echo "=============================================="
    ) &
    emulator -avd "${AVD_NAME}" \
      -accel off \
      -gpu swiftshader_indirect \
      -no-audio -no-boot-anim -no-snapshot \
      -memory "${EMULATOR_RAM_MB}" \
      -cores "${EMULATOR_CORES}" \
      -partition-size "${EMULATOR_PARTITION_MB}" \
      -no-metrics \
      ${EMULATOR_EXTRA_ARGS:-}
    echo "emulator exited (rc=$?), restarting in 2s" >&2
    sleep 2
  done
) &

# If any infra process dies (Xvfb, x11vnc, websockify, adb, appium), exit so Kubernetes restarts the container
wait -n
echo "a che-android service exited, terminating container" >&2
exit 1
