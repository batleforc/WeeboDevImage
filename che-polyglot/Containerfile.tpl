FROM @@REGISTRY@@/che-base:main

LABEL org.opencontainers.image.url="batleforc/che-polyglot"
LABEL org.opencontainers.image.title="Che-PolyglotImage"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"

ENV HOME=/home/tooling
USER 0

# START Infra Block

## Extra build deps useful when mise compiles tools from source
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3-dev \
      python3-pip \
      python3-venv \
      libyaml-dev \
      libreadline-dev \
      libncurses-dev \
      libbz2-dev \
      libsqlite3-dev \
      libffi-dev \
      zlib1g-dev \
      tk-dev \
      openjdk-21-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

## Install mise
RUN curl https://mise.run | sh && \
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ${GLOBALS_BASHRC} && \
    echo 'export MISE_TRUSTED_CONFIG_PATHS=/home/tooling/.config/mise:/home/user/.config/mise' >> ${GLOBALS_BASHRC}

## Default global mise config — tools are declared but installed at workspace start via `mise install`
RUN mkdir -p /home/tooling/.config/mise
COPY --chown=0:0 global.mise.toml /home/tooling/.config/mise/config.toml

# END Infra Block

ENV STAR_NO="true"

# START User Block
USER 1234
ENV HOME=/home/user
RUN stow . -t /home/user -d /home/tooling --no-folding
RUN cp -f /home/tooling/.bashrc /home/user/.bashrc
WORKDIR /home/user
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["tail", "-f", "/dev/null"]
