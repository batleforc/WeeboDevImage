# che-browser sidecar

Headed Chrome (Chrome for Testing) running behind Xvfb in a sidecar container of
the workspace pod. All containers share the pod network namespace, so every port
below is reachable from the tools container as `localhost`.

## Endpoints

| Port | What | Exposure |
|---|---|---|
| `6080` | noVNC web UI (watch/drive the real browser) | public endpoint |
| `9222` | Chrome DevTools Protocol (nginx proxy in front of Chrome) | `localhost` from the pod |
| `9515` | chromedriver (WebDriver) | `localhost` from the pod |

## For humans

- Open the `novnc` endpoint in your browser. The password is printed at the top
  of the `browser` container log and stored in
  `/projects/.sidecar/vnc-password-browser.txt` (readable from any container
  via the shared mount), or pin it by setting `VNC_PASSWORD` on the component.
- You see the same Chrome the automation drives — useful to watch a test run.
- Closing Chrome is safe: it respawns with the same profile after ~1s.

## For AI agents

Drive the browser from the tools container; verify results visually only if a
human asks — you get everything you need over CDP/WebDriver.

- Playwright (preferred): `chromium.connect_over_cdp("http://localhost:9222")`
  then use the existing browser context. Do not `launch()` a new browser.
- Selenium/WebDriver: remote driver against `http://localhost:9515`.
- Health check: `curl -s http://localhost:9222/json/version`.
- Screenshots: take them through Playwright/CDP (`page.screenshot`), not X11.
- The web app under test also runs in the pod, so point Chrome at
  `http://localhost:<port>` — no ingress needed.
- The sidecar mounts the workspace sources: Chrome can open
  `file:///projects/...` and downloads/artifacts can be exchanged with the
  tools container through `/projects`.

## Ready-made tasks

`Taskfile.example.yaml` (copy into your project) covers the common moves:
`cdp-version`, `tabs`, `open URL=…` (direct localhost ports), plus the
`kubectl exec $HOSTNAME -c browser` hop for `restart-chrome`, `vnc-password`,
`shell` and `logs`.

## Knobs (env on the `browser` component)

- `CHROME_START_URL` — page opened at boot (default `about:blank`)
- `CHROME_PROFILE_DIR` — profile location (default `/tmp/chrome-profile`, wiped on restart)
- `SCREEN_GEOMETRY` — screen size, `WxH` or `WxHxDEPTH` (default `1920x1080x24`,
  depth defaults to 24). Chrome's window is sized to fill the screen
- `VNC_PASSWORD` — fixed noVNC password instead of a generated one (set the
  same value on every sidecar for a single workspace-wide password)
- `NOVNC_PORT` / `VNC_PORT` — defaults `6080`/`5900`, staggered per sidecar so
  browser/android/desktop coexist in one pod; override via env if needed
  (keep the devfile endpoint's `targetPort` in sync)
- `XVFB_DISPLAY` — X display (default `:99`, staggered per sidecar). Use this,
  not `DISPLAY`: Che injects `DISPLAY=:0` into every container and the
  entrypoint re-exports `DISPLAY` from `XVFB_DISPLAY`
- `NO_START` — `true` parks Chrome at boot to keep the sidecar light at rest
  (default `false`; VNC stack stays up, chromedriver can still spawn its own
  Chrome). Toggle later with `sidecar-app start|stop|status` inside the
  container (`task app-start` from the example Taskfile)
