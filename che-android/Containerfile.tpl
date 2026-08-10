FROM @@BASE_UBUNTU_IMAGE@@

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-android"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-AndroidImage"

ENV ANDROID_CMDLINE_TOOLS_VERSION="@@SIDECAR_ANDROID_CMDLINE_TOOLS@@"
ENV ANDROID_API="@@SIDECAR_ANDROID_API@@"
ENV APPIUM_VERSION="@@SIDECAR_APPIUM@@"
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk

# xvfb/x11vnc/novnc: headed display + web view, tini: PID 1 reaping,
# openjdk: sdkmanager/avdmanager, nodejs/npm: Appium,
# the lib* set: emulator Qt UI + swiftshader runtime deps (26.04 t64 names)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    tini \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    openjdk-21-jre-headless \
    nodejs \
    npm \
    fonts-dejavu-core \
    libasound2t64 \
    libgl1 \
    libglu1-mesa \
    libnspr4 \
    libnss3 \
    libpulse0 \
    libx11-6 \
    libxcb1 \
    libxcb-cursor0 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxkbcommon0 \
    libxkbfile1 \
    libxrandr2 \
    libxrender1 \
    libxtst6 && \
    rm -rf /var/lib/apt/lists/* && \
    # the novnc package has no index.html, so the noVNC base URL would 404
    ln -s vnc.html /usr/share/novnc/index.html

# Android SDK: pinned cmdline-tools, then platform-tools + emulator + system image.
# platforms;android-N is installed because the emulator misbehaves without a
# platforms dir. chgrp/chmod must stay in this same RUN: a separate layer would
# duplicate the multi-GB SDK in the image.
RUN curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -o /tmp/cmdline-tools.zip && \
    mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip && \
    yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null && \
    ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "emulator" \
    "platforms;android-${ANDROID_API}" \
    "system-images;android-${ANDROID_API};google_apis;x86_64" && \
    chgrp -R 0 ${ANDROID_SDK_ROOT} && chmod -R g=u ${ANDROID_SDK_ROOT}

# APPIUM_HOME is set BEFORE the driver install so uiautomator2 lands in
# /opt/appium (root-owned, group-0 g=u) instead of root's ~/.appium
ENV APPIUM_HOME=/opt/appium
RUN npm install -g appium@${APPIUM_VERSION} && \
    mkdir -p ${APPIUM_HOME} && \
    appium driver install uiautomator2 && \
    npm cache clean --force && \
    chgrp -R 0 ${APPIUM_HOME} && chmod -R g=u ${APPIUM_HOME}

COPY --chown=0:0 entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    useradd -u 1234 -G root -d /home/user --shell /bin/bash -m user && \
    chgrp -R 0 /home/user && chmod -R g=u /home/user && \
    chmod g=u /etc/passwd

ENV HOME=/home/user
ENV DISPLAY=:98
ENV PATH=${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${PATH}
# AVD state lives under HOME: GID-0 writable, works for arbitrary UIDs
ENV ANDROID_USER_HOME=/home/user/.android
ENV ANDROID_AVD_HOME=/home/user/.android/avd
ENV AVD_NAME=che
ENV AVD_DEVICE=pixel_5
ENV EMULATOR_RAM_MB=3072
ENV EMULATOR_CORES=2
ENV EMULATOR_PARTITION_MB=4096
ENV LCD_WIDTH=720
ENV LCD_HEIGHT=1280
ENV LCD_DENSITY=320
ENV SCREEN_GEOMETRY=800x1400x24
# display/ports are staggered across the sidecars (browser :99/5900/6080,
# android :98/5901/6081, desktop :97/5902/6082) so they can share one pod
# netns without remapping; override via env if you run several of the same image.
# XVFB_DISPLAY (not DISPLAY) picks the display: Che's DevWorkspace operator
# force-injects DISPLAY=:0 into every container, so the entrypoint re-exports
# DISPLAY from XVFB_DISPLAY.
ENV XVFB_DISPLAY=:98
ENV NOVNC_PORT=6081
ENV VNC_PORT=5901
# Che pods have a tiny /dev/shm; keep the emulator's Qt UI off MIT-SHM
ENV QT_X11_NO_MITSHM=1

USER 1234
WORKDIR /home/user

# 6081 noVNC web UI, 4723 Appium; adb (5037) and emulator ports (5554/5555)
# stay on loopback and are reached from the tools container via the shared pod netns
EXPOSE 6081 4723

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
