FROM @@BASE_UBUNTU_IMAGE@@

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-browser"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-BrowserImage"

ENV CHROME_VERSION="@@BROWSER_CHROME@@"

# xvfb/x11vnc/novnc: headed display + web view, nginx-light: CDP proxy,
# tini: PID 1 reaping Chrome zombies, the lib* set: Chrome runtime deps (26.04 t64 names)
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
    nginx-light \
    dbus \
    dbus-x11 \
    fonts-liberation \
    fonts-dejavu-core \
    fonts-noto-color-emoji \
    libasound2t64 \
    libatk-bridge2.0-0t64 \
    libatk1.0-0t64 \
    libatspi2.0-0t64 \
    libcairo2 \
    libcups2t64 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libglib2.0-0t64 \
    libgtk-3-0t64 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxrender1 \
    xdg-utils && \
    rm -rf /var/lib/apt/lists/*

# Version-matched Chrome for Testing + chromedriver (single pinned version covers both)
RUN curl -fsSL "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip" -o /tmp/chrome.zip && \
    curl -fsSL "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip" -o /tmp/chromedriver.zip && \
    unzip -q /tmp/chrome.zip -d /opt && \
    mv /opt/chrome-linux64 /opt/chrome && \
    unzip -q /tmp/chromedriver.zip -d /tmp && \
    install -m 0755 /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver && \
    ln -s /opt/chrome/chrome /usr/bin/google-chrome && \
    ln -s /opt/chrome/chrome /usr/local/bin/chrome && \
    rm -rf /tmp/chrome.zip /tmp/chromedriver.zip /tmp/chromedriver-linux64

COPY --chown=0:0 nginx-cdp.conf /etc/che-browser/nginx-cdp.conf
COPY --chown=0:0 entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    useradd -u 1234 -G root -d /home/user --shell /bin/bash -m user && \
    chgrp -R 0 /home/user && chmod -R g=u /home/user && \
    chmod g=u /etc/passwd

ENV HOME=/home/user
ENV DISPLAY=:99
ENV CHROME_PROFILE_DIR=/tmp/chrome-profile
ENV SCREEN_GEOMETRY=1920x1080x24
ENV CHROME_START_URL=about:blank

USER 1234
WORKDIR /home/user

# 9222 CDP proxy (Playwright connectOverCDP), 9515 chromedriver, 6080 noVNC web UI
EXPOSE 9222 9515 6080

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
