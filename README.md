# Weebo's Dev Images

This is a collection of images that I use in my Dev Env. In the past those images were stored in my personal registry, but now it's time to move them to github.

## Images actively built

These images are built and pushed to `ghcr.io/batleforc/weebodevimage` on every push to `main` and every night.

| Image | Base | Description |
|---|---|---|
| `che-min-mise` | `ubuntu:26.04` | Minimal tooling image (mise, kubectl, FiraCode, shell setup). Serves as the `tools` component in the sidecar devfiles and as the base for `che-mise-pdm`. |
| `che-mise-pdm` | `che-min-mise` | `che-min-mise` + Podman (rootless nested containers, `containers.conf`/`registries.conf` preconfigured). |
| `che-mise-webkit` | `che-min-mise` | `che-min-mise` + WebKitGTK dev stack (Tauri Linux prerequisites: `libwebkit2gtk-4.1-dev`, appindicator, xdo, ssl, rsvg), with Xvfb/D-Bus so apps can run headless in the workspace. |
| `che-vscode` | `quay.io/che-incubator/che-code` | Eclipse Che VS Code editor with a custom volume entrypoint. |
| `che-android` | `ubuntu:26.04` | Sidecar: Android 15 (API 35) emulator, CPU-only (no KVM/GPU — QEMU TCG + SwiftShader, expect a slow cold boot), viewable via noVNC (`6080`), with adb (`localhost:5037`) and Appium + uiautomator2 (`4723`). amd64 only. |
| `che-browser` | `ubuntu:26.04` | Sidecar: headed Chrome behind Xvfb, viewable via noVNC (`6080`), with an nginx CDP proxy (`9222`) and webdriver (`9515`). |
| `che-desktop` | `ubuntu:26.04` | Sidecar: Xvfb + openbox desktop for validating desktop apps (Tauri/Electron/GTK runtime libs, D-Bus session, Mesa software GL), viewable via noVNC (`6080`). Set `DESKTOP_APP_CMD` to respawn the app built in `/projects`; otherwise an xterm is provided. |
| `che-kubedock` | `ubuntu:26.04` | Sidecar: [kubedock](https://github.com/joyrex2001/kubedock) — a Docker API that spins up containers as Kubernetes pods (`2475`). |
| `che-lgtm` | `grafana/otel-lgtm` | Sidecar: Grafana LGTM observability stack (Loki, Grafana, Tempo, Mimir + OTel collector). |
| `che-mailpit` | `ubuntu:26.04` | Sidecar: [Mailpit](https://github.com/axllent/mailpit) SMTP testing server with web UI. |
| `che-rustfs` | `ubuntu:26.04` | Sidecar: [RustFS](https://github.com/rustfs/rustfs) S3-compatible object storage. |

Each sidecar folder ships a `devfile.yaml` combining `che-min-mise` (tools) with the sidecar itself. The `che-browser`, `che-android` and `che-desktop` folders also ship an `AGENTS.md` documenting the sidecar's endpoints and how humans and AI agents should use it — copy it into your project so coding agents pick it up — plus a `Taskfile.example.yaml` with ready-made tasks that hop into the sidecar container via `kubectl exec $HOSTNAME -c <sidecar>`.

## Disabled images

The following images are kept in the repo for reference but are no longer built (see `disabled_images` in [`versions.yaml`](versions.yaml)): `che-min`, `che-base`, `che-base-slim`, `che-golang`, `che-node`, `che-rust`, `che-polyglot`, `che-mise`, `che-ops`.

Their last built tags remain available on ghcr.io but will not receive updates. Remove an entry from `disabled_images` to re-enable a build.

## Development

- `task render` — regenerate `Containerfile`/`devfile.yaml` from templates and `versions.yaml`
- `task lint` — check that rendered files match their templates
- `task build IMAGE=che-browser` — build one image locally
- `task build-all` — build every active image in dependency order

## TODO

- Redo the Web Terminal ide with the ghostty web lib https://github.com/coder/ghostty-web
    - Check wich one is the better redo
        - https://github.com/tsl0922/ttyd
        - https://github.com/che-incubator/chemuxer
    - Validate the compatibility with ghostty official api
    - For the Fun, do a fastfetch
    - Add the idle capabiliti