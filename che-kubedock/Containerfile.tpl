FROM @@BASE_UBUNTU_IMAGE@@

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-kubedock"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-KubedockImage"

ENV KUBEDOCK_VERSION="@@BASE_TOOLS_KUBEDOCK@@"

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tini && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/joyrex2001/kubedock/releases/download/${KUBEDOCK_VERSION}/kubedock_linux_x86_64.tar.gz | \
    tar -C /usr/local/bin/ -xzf - kubedock && \
    chmod +x /usr/local/bin/kubedock

COPY --chown=0:0 entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    useradd -u 1234 -G root -d /home/user --shell /bin/bash -m user && \
    chgrp -R 0 /home/user && chmod -R g=u /home/user && \
    chmod g=u /etc/passwd

ENV HOME=/home/user
ENV KUBEDOCK_LISTEN_ADDR=:2475

USER 1234
WORKDIR /home/user

# 2475: Docker API backed by Kubernetes pods (DOCKER_HOST=tcp://localhost:2475)
EXPOSE 2475

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
