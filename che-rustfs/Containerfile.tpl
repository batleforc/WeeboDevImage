FROM @@BASE_UBUNTU_IMAGE@@

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-rustfs"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-RustFSImage"

ENV RUSTFS_VERSION="@@SIDECAR_RUSTFS@@"

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    tini && \
    rm -rf /var/lib/apt/lists/*

# musl build: static binary, no extra runtime deps
RUN curl -fsSL "https://github.com/rustfs/rustfs/releases/download/${RUSTFS_VERSION}/rustfs-linux-x86_64-musl-v${RUSTFS_VERSION}.zip" -o /tmp/rustfs.zip && \
    unzip -q /tmp/rustfs.zip -d /tmp/rustfs-extract && \
    install -m 0755 "$(find /tmp/rustfs-extract -type f -name rustfs | head -n1)" /usr/local/bin/rustfs && \
    rm -rf /tmp/rustfs.zip /tmp/rustfs-extract

COPY --chown=0:0 entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    useradd -u 1234 -G root -d /home/user --shell /bin/bash -m user && \
    chgrp -R 0 /home/user && chmod -R g=u /home/user && \
    chmod g=u /etc/passwd

ENV HOME=/home/user
# dev credentials, override via devfile env for anything shared
ENV RUSTFS_VOLUMES=/home/user/rustfs-data
ENV RUSTFS_ADDRESS=:9000
ENV RUSTFS_CONSOLE_ENABLE=true
ENV RUSTFS_ACCESS_KEY=rustfsadmin
ENV RUSTFS_SECRET_KEY=rustfsadmin

USER 1234
WORKDIR /home/user

# 9000 S3 API, 9001 web console
EXPOSE 9000 9001

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
