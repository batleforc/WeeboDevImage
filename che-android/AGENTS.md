# che-android sidecar

Android emulator (API 35, google_apis x86_64) with adb and Appium in a sidecar
container of the workspace pod. CPU-only emulation (no KVM/GPU): expect a
multi-minute cold boot. amd64 only. All ports below are reachable from the
tools container as `localhost` via the shared pod network namespace.

## Endpoints

| Port | What | Exposure |
|---|---|---|
| `6081` | noVNC web UI (emulator screen) | public endpoint |
| `4723` | Appium server (uiautomator2 driver preinstalled) | `localhost` from the pod |
| `5037` | adb server | `localhost` from the pod |

## For humans

- Open the `novnc` endpoint to see and touch the emulator. The password is
  printed at the top of the `android` container log and stored in
  `/projects/.sidecar/vnc-password-android.txt` (readable from any container
  via the shared mount), or pin it with `VNC_PASSWORD`.
- Boot progress is logged (`android: still booting…` then `boot completed`).
- If you close the emulator window, it respawns (cold boot again).

## For AI agents

The devfile already sets `ADB_SERVER_SOCKET=tcp:localhost:5037` and
`APPIUM_URL=http://localhost:4723` in the tools container.

- Wait for boot before doing anything:
  `adb wait-for-device && adb shell getprop sys.boot_completed` → `1`.
  Be patient — software emulation means minutes, not seconds; poll, don't fail.
- You need the adb *client* in tools (e.g. platform-tools via mise or a
  downloaded zip); it talks to the sidecar's adb *server*, so no device setup.
- The sidecar mounts the workspace sources: an apk built in tools is visible
  at the same `/projects/...` path inside the sidecar.
- Install & run: `adb install -r app-debug.apk`,
  `adb shell am start -n <pkg>/<activity>`, logs via `adb logcat`.
- Screenshots: `adb exec-out screencap -p > screen.png` — use this to check UI
  state instead of noVNC.
- UI automation: Appium at `http://localhost:4723` (driver `uiautomator2`,
  started with `--allow-cors --relaxed-security`).
- AVD state lives in the sidecar's `$HOME` (ephemeral): assume a factory-reset
  device on every container restart.

## Ready-made tasks

`Taskfile.example.yaml` (copy into your project) wraps the
`kubectl exec $HOSTNAME -c android` hop into tasks — no adb client needed in
tools: `wait-boot`, `adb -- <args>`, `install APK=…` (the sidecar mounts
`/projects`, so apks built in tools install straight from their path),
`run COMPONENT=…`, `screenshot`, `logcat`, `shell`, `vnc-password`, `logs`.

## Knobs (env on the `android` component)

- `AVD_DEVICE` (default `pixel_5`), `LCD_WIDTH`/`LCD_HEIGHT`/`LCD_DENSITY`
- `EMULATOR_RAM_MB`, `EMULATOR_CORES`, `EMULATOR_PARTITION_MB`, `EMULATOR_EXTRA_ARGS`
- `SCREEN_GEOMETRY` — Xvfb size (default `800x1400x24`)
- `VNC_PASSWORD` — fixed noVNC password instead of a generated one (set the
  same value on every sidecar for a single workspace-wide password)
- `NOVNC_PORT` / `VNC_PORT` — defaults `6081`/`5901`, staggered per sidecar so
  browser/android/desktop coexist in one pod; override via env if needed
  (keep the devfile endpoint's `targetPort` in sync)
- `XVFB_DISPLAY` — X display (default `:98`, staggered per sidecar). Use this,
  not `DISPLAY`: Che injects `DISPLAY=:0` into every container and the
  entrypoint re-exports `DISPLAY` from `XVFB_DISPLAY`
- `NO_START` — `true` parks the emulator at boot to keep the sidecar light at
  rest (default `false`; VNC/adb/appium stay up). Toggle later with
  `sidecar-app start|stop|status` inside the container (`task app-start` from
  the example Taskfile); expect the usual multi-minute cold boot after start
