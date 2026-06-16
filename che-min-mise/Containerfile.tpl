FROM @@BASE_UBUNTU_IMAGE@@

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-min-mise"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-Min-MiseImage"

ENV KUBE_VERSION="@@MIN_KUBECTL@@"
ENV FIRACODE_VERSION="@@MIN_FIRACODE@@"
ENV MISE_VERSION="@@BASE_TOOLS_MISE@@"

ENV HOME=/home/tooling
ENV NVM_DIR=/home/tooling/.nvm

ENV GLOBALS_FOLDER="/globals/"
ENV GLOBALS_BASHRC="${GLOBALS_FOLDER}bashrc"

RUN mkdir -p ${GLOBALS_FOLDER} && touch ${GLOBALS_BASHRC} && chmod -R 777 ${GLOBALS_FOLDER} && mkdir -p /home/tooling && \
    echo 'source /globals/bashrc' >> ${HOME}/.bashrc && \
    echo "alias ll='ls -alF'" >> ${GLOBALS_BASHRC} && \
    echo "alias la='ls -A'" >> ${GLOBALS_BASHRC} && \
    echo "alias l='ls -CF'" >> ${GLOBALS_BASHRC} && \
    echo "alias k='kubectl'" >> ${GLOBALS_BASHRC} && \
    echo "alias n='nvim'" >> ${GLOBALS_BASHRC} && \
    echo "alias kns='kubectl config set-context --current --namespace'" >> ${GLOBALS_BASHRC}

# Core packages: replaces buildpack-deps, adds locale + completion + nested container support (uidmap)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    ca-certificates \
    git \
    git-lfs \
    bash-completion \
    libc6 \
    locales \
    uidmap \
    unzip \
    fontconfig \
    zip \ 
    gnupg2 \
    vim \
    stow \
    net-tools \
    libnode-dev \
    less \
    htop \
    neovim \
    pkg-config &&\
    rm -rf /var/lib/apt/lists/* &&\
    mkdir -p /home/tooling/ &&\
    echo "source /etc/profile.d/bash_completion.sh" >> ${GLOBALS_BASHRC} &&\
    locale-gen "en_US.UTF-8" &&\
    echo 'export GPG_TTY=$(tty)' >> ${GLOBALS_BASHRC} && \
    echo 'alias load-priv="gpg --import /etc/gpgkey/keypriv.asc"' >> ${GLOBALS_BASHRC} && \
    echo 'alias load-pub="gpg --import /etc/gpgkey/keypub.asc"' >> ${GLOBALS_BASHRC} && \
    curl -sS https://starship.rs/install.sh | sh -s -- -y && \
    echo '[ $STAR_NO != "false" ] && eval "$(starship init bash)" ' >> ${GLOBALS_BASHRC} && \
    mkdir -p /home/tooling/.local/bin && \
    curl -fsSL https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-x64 \
    -o /home/tooling/.local/bin/mise && \
    chmod +x /home/tooling/.local/bin/mise && \
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ${GLOBALS_BASHRC} && \
    echo 'export MISE_TRUSTED_CONFIG_PATHS=/home/tooling/.config/mise:/home/user/.config/mise:/mounted/mise:/projects' >> ${GLOBALS_BASHRC} &&\
    curl -fsSLo /usr/local/bin/kubectl \
    https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    kubectl completion bash > /etc/bash_completion.d/kubectl && \
    echo 'source /etc/bash_completion.d/kubectl' >> ${GLOBALS_BASHRC} && \
    tmpdir="$(mktemp -d)" && cd "${tmpdir}" && \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/${FIRACODE_VERSION}/FiraCode.zip -o FiraCode.zip && \
    unzip FiraCode.zip && \
    mkdir -p /usr/local/share/fonts && \
    cp FiraCode*.ttf /usr/local/share/fonts && \
    rm FiraCode.zip && \
    fc-cache -f -v && \
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /home/tooling/.local/bin && \
    rm -rf "${tmpdir}" && cd -

ENV KUBECONFIG=/home/user/.kube/config
ENV LANG="en_US.UTF-8"
ENV STAR_NO="true"
COPY starship.toml ${HOME}/.config/starship.toml
COPY --chown=0:0 .stow-local-ignore /home/tooling/
COPY --chown=0:0 entrypoint.sh /


## https://github.com/devfile/developer-images/blob/main/universal/ubi8/entrypoint.sh

RUN mkdir -p /home/tooling/.local/bin && \
    chgrp -R 0 /home && chmod -R g=u /home && \
    useradd -u 1234 -G root -d /home/user --shell /bin/bash -m user && \
    touch /etc/subgid /etc/subuid  && \
    chmod g=u /etc/subgid /etc/subuid /etc/passwd  && \
    echo user:10000:65536 > /etc/subuid  && \
    echo user:10000:65536 > /etc/subgid
ENV PATH="/home/user/.local/bin:$PATH"
ENV PATH="/home/tooling/.local/bin:$PATH"

COPY --chown=0:0 .copy-files /home/tooling/

## Try a fix for path not found

RUN echo 'export PATH="/home/tooling/.local/bin:$PATH"' >> ${GLOBALS_BASHRC} && \
    echo 'export PATH="/home/user/.local/bin:$PATH"' >> ${GLOBALS_BASHRC} && \
    echo 'export PATH="/checode/checode-linux-libc/ubi9/bin/remote-cli:$PATH"' >> ${GLOBALS_BASHRC} && \
    echo '[ -f "/home/user/.bashrc_perso" ] && source /home/user/.bashrc_perso'  >> ${GLOBALS_BASHRC} && \
    chmod g=u /etc/passwd /etc/group && \
    chgrp -R 0 /home/tooling && chmod -R g=u /home/tooling && \
    mkdir -p /home/user && \
    chgrp -R 0 /home && chmod -R g=u /etc/passwd /etc/group /home && \
    chmod +x /entrypoint.sh

USER 1234
RUN cp -f /home/tooling/.bashrc /home/user/.bashrc && \
    stow . -t /home/user/ -d /home/tooling/ --no-folding
ENV HOME=/home/user
WORKDIR /projects
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["sleep","infinity"]