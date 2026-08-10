# che-desktop sidecar

A minimal X desktop (Xvfb + openbox + D-Bus session) for running and validating
desktop applications — Tauri, Electron and GTK runtime libraries plus Mesa
software GL are preinstalled. The sidecar mounts the workspace sources, so a
binary built in the tools container is directly runnable from `/projects`.

## Endpoints

| Port | What | Exposure |
|---|---|---|
| `6082` | noVNC web UI (the desktop itself) | public endpoint |

There is no network automation endpoint: the primary interface is visual.

## For humans

- Open the `novnc` endpoint to see the desktop. The password is printed at the
  top of the `desktop` container log and stored in
  `/projects/.sidecar/vnc-password-desktop.txt` (readable from any container
  via the shared mount), or pin it with `VNC_PASSWORD`.
- Set `DESKTOP_APP_CMD` (e.g. `/projects/myapp/src-tauri/target/release/myapp`)
  to have your app launched and respawned automatically; close its window via
  noVNC to relaunch a freshly rebuilt binary.
- With no `DESKTOP_APP_CMD`, an xterm is kept open on the display so you can
  launch anything by hand.

## For AI agents

Your job here is usually "does the app build, start, and stay up" — the visual
check belongs to the human via noVNC.

- Build in the tools container as usual; the binary lands in `/projects/...`,
  which the `desktop` container sees at the same path.
- The app's stdout/stderr and crash/respawn messages
  (`desktop app exited (rc=…)`) go to the `desktop` container log — read that
  to confirm the app started or to get its error output after a change.
- Electron apps need `--no-sandbox` in `DESKTOP_APP_CMD`; Tauri and GTK apps
  need nothing special. There is no GPU: GL goes through Mesa software
  rendering (slow but correct).
- `xdotool` (synthetic input, window queries) and `scrot` (screenshots) are
  installed *in the sidecar*. If you can exec into the `desktop` container
  (terminal in the editor, or `kubectl exec -c desktop` on this pod), save
  screenshots under `/projects` so you can read them from the tools container:
  `DISPLAY=:97 scrot /projects/shot.png`.

## Ready-made tasks

`Taskfile.example.yaml` (copy into your project) wraps the
`kubectl exec $HOSTNAME -c desktop` hop into tasks: `shell`, `vnc-password`,
`logs`, `screenshot` (saved under `/projects` so tools can read it), `windows`,
`key`/`type`/`click` (xdotool), and `app-restart`.

## Knobs (env on the `desktop` component)

- `DESKTOP_APP_CMD` — command to run & respawn (default empty → xterm)
- `DESKTOP_APP_CWD` — working directory for it (default `/projects`)
- `DESKTOP_APP_RESTART_DELAY` — seconds between respawns (default `2`)
- `SCREEN_GEOMETRY` — Xvfb size (default `1920x1080x24`)
- `VNC_PASSWORD` — fixed noVNC password instead of a generated one (set the
  same value on every sidecar for a single workspace-wide password)
- `NOVNC_PORT` / `VNC_PORT` — defaults `6082`/`5902`, staggered per sidecar so
  browser/android/desktop coexist in one pod; override via env if needed
  (keep the devfile endpoint's `targetPort` in sync)
- `XVFB_DISPLAY` — X display (default `:97`, staggered per sidecar). Use this,
  not `DISPLAY`: Che injects `DISPLAY=:0` into every container and the
  entrypoint re-exports `DISPLAY` from `XVFB_DISPLAY`
- `NO_START` — `true` parks the app/xterm at boot to keep the sidecar light at
  rest (default `false`; VNC stack and openbox stay up). Toggle later with
  `sidecar-app start|stop|status` inside the container (`task app-start` from
  the example Taskfile)
