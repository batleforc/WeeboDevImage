FROM grafana/otel-lgtm:@@SIDECAR_LGTM@@

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-lgtm"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-LGTMImage"

COPY --chown=0:0 entrypoint.sh /entrypoint.sh

# UBI-micro base has no useradd: append the passwd entry directly.
# /otel-lgtm + /data + /etc/lgtm are written by run-all.sh at runtime.
RUN chmod +x /entrypoint.sh && \
    mkdir -p /home/user /data /etc/lgtm && \
    echo "user:x:1234:0:container user:/home/user:/bin/bash" >> /etc/passwd && \
    chgrp -R 0 /home/user /data /etc/lgtm /otel-lgtm && \
    chmod -R g=u /home/user /data /etc/lgtm /otel-lgtm && \
    chmod g=u /etc/passwd

ENV HOME=/home/user

USER 1234
WORKDIR /otel-lgtm

# 3000 Grafana (admin/admin), 4317 OTLP gRPC, 4318 OTLP HTTP
EXPOSE 3000 4317 4318

ENTRYPOINT ["/entrypoint.sh"]
