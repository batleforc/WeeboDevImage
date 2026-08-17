#!/bin/sh
#
# Weebo customizations layered on top of the upstream che-code entrypoint.
#
# The che-code base image already provides /entrypoint-volume.sh; we do NOT ship
# our own copy. Everything weebo-specific lives HERE, then we exec the base
# image's upstream entrypoint — so a che-code bump needs no re-merge.
#

WORKBENCH_PATH="/checode/checode-linux-libc/ubi9/out/vs/code/browser/workbench"
CLI_DIR="/checode/checode-linux-libc/ubi9/bin/remote-cli"

# --- Fonts: expose system fonts to the workbench + register FiraCode Nerd Font
if [ -d "${WORKBENCH_PATH}" ]; then
  if [ ! -e "${WORKBENCH_PATH}/fonts" ] && ln -s /usr/share/fonts/ "${WORKBENCH_PATH}/fonts" 2>/dev/null; then
    echo "[INFO][weebo] Font dir linked into workbench"
  fi
  CSS_FILE="${WORKBENCH_PATH}/workbench.css"
  FONT_NAME="FiraCode Nerd Font"
  if [ -f "${CSS_FILE}" ] && ! grep -qF "${FONT_NAME}" "${CSS_FILE}"; then
    echo "[INFO][weebo] Injecting '${FONT_NAME}' into workbench.css"
    printf '\n@font-face { font-family: "%s"; src: url("fonts/FiraCodeNerdFont-Medium.ttf") format("truetype"); }\n' "${FONT_NAME}" >> "${CSS_FILE}"
  fi
fi

# --- Provide a `code` alias for the remote CLI (upstream ships code-oss) -----
if [ ! -e "${CLI_DIR}/code" ] && [ -e "${CLI_DIR}/code-oss" ]; then
  ln -s "${CLI_DIR}/code-oss" "${CLI_DIR}/code" 2>/dev/null && echo "[INFO][weebo] Linked code -> code-oss"
fi

# Hand off to the base image's upstream entrypoint (does its own cd + node launch).
exec /entrypoint-volume-root.sh
