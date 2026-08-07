FROM @@REGISTRY@@/che-min-mise:main
# @@BASE_CHE_MIN_MISE_IMAGE@@ -> ghcr.io/batleforc/weebodevimage/che-min-mise:main

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-mise-webkit"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-Min-Mise-Webkit"

USER 0

# WebKitGTK app development (Tauri & friends) on top of the lean base:
# libwebkit2gtk-4.1-dev pulls the GTK 3 headers it sits on, the appindicator/
# xdo/ssl/rsvg set covers the Tauri Linux prerequisites, and Xvfb + the
# session/a11y buses (dbus-x11/at-spi2-core) let the app run headless in the
# workspace. pkg-config/build-essential are already provided by che-min-mise.
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
    libwebkit2gtk-4.1-dev \
    libayatana-appindicator3-dev \
    libxdo-dev \
    libssl-dev \
    librsvg2-dev \
    file \
    gettext \
    desktop-file-utils \
    adwaita-icon-theme \
    at-spi2-core \
    dbus-x11 \
    xvfb \
    xauth && \
    rm -rf /var/lib/apt/lists/*

USER 1234
WORKDIR /projects
