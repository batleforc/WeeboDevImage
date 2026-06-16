FROM @@REGISTRY@@/che-base:main

LABEL org.opencontainers.image.url="batleforc/che-rust"
LABEL org.opencontainers.image.title="Che-RustImage"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"

ENV HOME=/home/tooling
USER 0

# START Infra Block

ENV RUSTUP_HOME=/home/tooling/.rustup \
    CARGO_HOME=/home/tooling/.cargo  \
    PATH=/home/tooling/.cargo/bin:$PATH \
    RUST_VERSION=@@RUST_VERSION@@ \
    GLOBALS_FOLDER="/globals/" \
    GLOBALS_BASHRC="${GLOBALS_FOLDER}bashrc"

RUN apt-get update && apt-get install -y --no-install-recommends libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN echo 'export RUSTUP_HOME=/home/user/.rustup' >> ${GLOBALS_BASHRC} && \
    echo 'export CARGO_HOME=/home/user/.cargo' >> ${GLOBALS_BASHRC} && \
    echo 'export PATH="/home/user/.cargo/bin:$PATH"' >> ${GLOBALS_BASHRC}

RUN set -eux; \
    cat ${GLOBALS_BASHRC}; \
    source ${GLOBALS_BASHRC}; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
    amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='@@RUSTUP_SHA256_AMD64@@' ;; \
    armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='@@RUSTUP_SHA256_ARMHF@@' ;; \
    arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='@@RUSTUP_SHA256_ARM64@@' ;; \
    i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='@@RUSTUP_SHA256_I386@@' ;; \
    ppc64el) rustArch='powerpc64le-unknown-linux-gnu'; rustupSha256='@@RUSTUP_SHA256_PPC64EL@@' ;; \
    s390x) rustArch='s390x-unknown-linux-gnu'; rustupSha256='@@RUSTUP_SHA256_S390X@@' ;; \
    *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/@@RUSTUP_VERSION@@/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup --version; \
    cargo --version; \
    rustc --version;\
    rustup completions bash > /etc/bash_completion.d/rustup && \
    echo 'source /etc/bash_completion.d/rustup' >> ${GLOBALS_BASHRC} && \
    rustup completions bash cargo > /etc/bash_completion.d/cargo && \
    echo 'source /etc/bash_completion.d/cargo' >> ${GLOBALS_BASHRC} && \
    chmod g=u /etc/passwd /etc/group


# END Infra Block

ENV STAR_NO="true"

USER 1234
ENV HOME=/home/user
RUN stow . -t /home/user -d /home/tooling --no-folding && \
    cp -f /home/tooling/.bashrc /home/user/.bashrc
WORKDIR /home/user
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["sleep","infinity"]
