FROM @@BASE_UBUNTU_IMAGE@@

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-min-mise"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-Min-MiseImage"

ENV HOME=/home/tooling

ENV GLOBALS_FOLDER="/globals/"
ENV GLOBALS_BASHRC="${GLOBALS_FOLDER}bashrc"
# Aliases and environment shared by bash and zsh; each shell rc sources it
ENV GLOBALS_SHELLRC="${GLOBALS_FOLDER}shellrc"

# Group 0 is enough: the arbitrary UID Che runs with is always in the root group
RUN mkdir -p ${GLOBALS_FOLDER} && touch ${GLOBALS_BASHRC} ${GLOBALS_SHELLRC} && \
    chgrp -R 0 ${GLOBALS_FOLDER} && chmod 775 ${GLOBALS_FOLDER} && chmod 664 ${GLOBALS_BASHRC} ${GLOBALS_SHELLRC} && \
    mkdir -p /home/tooling && \
    echo 'source /globals/bashrc' >> ${HOME}/.bashrc && \
    echo '# USER_SHELL=zsh: hand interactive shells over to zsh, whatever the login shell is.' >> ${GLOBALS_BASHRC} && \
    echo '# USER_SHELL_HANDOFF is inherited, so a `bash` typed from zsh stays bash.' >> ${GLOBALS_BASHRC} && \
    echo '[[ $- == *i* ]] && [ "${USER_SHELL:-bash}" = "zsh" ] && [ -z "${USER_SHELL_HANDOFF:-}" ] && command -v zsh >/dev/null && USER_SHELL_HANDOFF=1 exec zsh' >> ${GLOBALS_BASHRC} && \
    echo 'source /globals/shellrc' >> ${GLOBALS_BASHRC} && \
    echo "alias ll='ls -alF'" >> ${GLOBALS_SHELLRC} && \
    echo "alias la='ls -A'" >> ${GLOBALS_SHELLRC} && \
    echo "alias l='ls -CF'" >> ${GLOBALS_SHELLRC} && \
    echo "alias k='kubectl'" >> ${GLOBALS_SHELLRC} && \
    echo "alias n='nvim'" >> ${GLOBALS_SHELLRC} && \
    echo "alias vim='nvim'" >> ${GLOBALS_SHELLRC} && \
    echo "alias kns='kubectl config set-context --current --namespace'" >> ${GLOBALS_SHELLRC}

# Core packages: replaces buildpack-deps, adds locale + completion + nested container support (uidmap).
# Kept apart from the versioned tools below so a tool bump does not rebuild (and re-pull) this layer.
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    make \
    curl \
    wget \
    ca-certificates \
    git \
    git-lfs \
    bash-completion \
    tini \
    locales \
    uidmap \
    unzip \
    fontconfig \
    zip \
    gnupg2 \
    pinentry-curses \
    stow \
    net-tools \
    less \
    htop \
    neovim \
    ripgrep \
    lazygit \
    fzf \
    zsh \
    eza \
    libdbus-1-dev \
    libclang-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen "en_US.UTF-8" && \
    echo "source /etc/profile.d/bash_completion.sh" >> ${GLOBALS_BASHRC} && \
    echo 'export GPG_TTY=$(tty)' >> ${GLOBALS_SHELLRC} && \
    echo 'alias load-priv="gpg --import /etc/gpgkey/keypriv"' >> ${GLOBALS_SHELLRC} && \
    echo 'alias load-pub="gpg --import /etc/gpgkey/keypub"' >> ${GLOBALS_SHELLRC} && \
    echo 'eval "$(fzf --bash)"' >> ${GLOBALS_BASHRC} && \
    echo 'skip_global_compinit=1' >> /etc/zsh/zshenv

ENV KUBE_VERSION="@@MIN_KUBECTL@@"
ENV FIRACODE_VERSION="@@MIN_FIRACODE@@"
ENV STARSHIP_VERSION="@@MIN_STARSHIP@@"
ENV CHEZMOI_VERSION="@@MIN_CHEZMOI@@"
ENV MISE_VERSION="@@BASE_TOOLS_MISE@@"
ENV BATLEHUB_CLI_VERSION="@@MIN_BATLEHUB_CLI@@"

# Versioned tools, each checked against the sha256 its release publishes
RUN tmpdir="$(mktemp -d)" && cd "${tmpdir}" && \
    mkdir -p /home/tooling/.local/bin /usr/local/share/fonts && \
    curl -fsSLO https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz && \
    echo "$(curl -fsSL https://github.com/starship/starship/releases/download/${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz.sha256)  starship-x86_64-unknown-linux-musl.tar.gz" | sha256sum -c - && \
    tar xzf starship-x86_64-unknown-linux-musl.tar.gz -C /usr/local/bin starship && \
    echo '[[ $- == *i* ]] && [ "$STARSHIP_ENABLED" != "false" ] && eval "$(starship init bash)"' >> ${GLOBALS_BASHRC} && \
    curl -fsSLO https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-x64 && \
    curl -fsSLO https://github.com/jdx/mise/releases/download/${MISE_VERSION}/SHASUMS256.txt && \
    grep " ./mise-${MISE_VERSION}-linux-x64$" SHASUMS256.txt | sha256sum -c - && \
    install -m 755 mise-${MISE_VERSION}-linux-x64 /home/tooling/.local/bin/mise && \
    echo 'eval "$(~/.local/bin/mise activate bash --shims)"' >> ${GLOBALS_BASHRC} && \
    echo 'export MISE_TRUSTED_CONFIG_PATHS=/home/tooling/.config/mise:/home/user/.config/mise:/mounted/mise:/projects' >> ${GLOBALS_SHELLRC} && \
    curl -fsSLO https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl && \
    echo "$(curl -fsSL https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl.sha256)  kubectl" | sha256sum -c - && \
    install -m 755 kubectl /usr/local/bin/kubectl && \
    kubectl completion bash > /etc/bash_completion.d/kubectl && \
    echo 'source /etc/bash_completion.d/kubectl' >> ${GLOBALS_BASHRC} && \
    curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/${FIRACODE_VERSION}/FiraCode.zip && \
    curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/${FIRACODE_VERSION}/SHA-256.txt && \
    grep ' FiraCode.zip$' SHA-256.txt | sha256sum -c - && \
    unzip -q FiraCode.zip 'FiraCode*.ttf' -d /usr/local/share/fonts && \
    fc-cache -f && \
    curl -fsSLO https://github.com/twpayne/chezmoi/releases/download/${CHEZMOI_VERSION}/chezmoi-linux-amd64 && \
    curl -fsSLO https://github.com/twpayne/chezmoi/releases/download/${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION#v}_checksums.txt && \
    grep ' chezmoi-linux-amd64$' chezmoi_${CHEZMOI_VERSION#v}_checksums.txt | sha256sum -c - && \
    install -m 755 chezmoi-linux-amd64 /home/tooling/.local/bin/chezmoi && \
    curl -fsSLO https://github.com/batleforc/batlehub/releases/download/${BATLEHUB_CLI_VERSION}/batlehub-cli-linux-amd64.tar.gz && \
    curl -fsSLO https://github.com/batleforc/batlehub/releases/download/${BATLEHUB_CLI_VERSION}/checksums.txt && \
    grep ' batlehub-cli-linux-amd64.tar.gz$' checksums.txt | sha256sum -c - && \
    tar xzf batlehub-cli-linux-amd64.tar.gz -C /home/tooling/.local/bin batlehub-cli && \
    /home/tooling/.local/bin/batlehub-cli completion bash > /etc/bash_completion.d/batlehub-cli && \
    mkdir -p /usr/local/share/zsh/site-functions && \
    /home/tooling/.local/bin/batlehub-cli completion zsh > /usr/local/share/zsh/site-functions/_batlehub-cli && \
    cd / && rm -rf "${tmpdir}" && \
    chgrp -R 0 /home/tooling && chmod -R g=u /home/tooling

# oh-my-zsh for USER_SHELL=zsh, in its own layer: it is pinned to a master
# commit and moves far more often than the tools above.
# Fetched by commit id so git checks the content; .git is dropped afterwards.
ENV OHMYZSH_COMMIT="@@MIN_OHMYZSH@@"
ENV ZSH_AUTOSUGGESTIONS_VERSION="@@MIN_ZSH_AUTOSUGGESTIONS@@"
ENV ZSH_SYNTAX_HIGHLIGHTING_VERSION="@@MIN_ZSH_SYNTAX_HIGHLIGHTING@@"

RUN mkdir -p /home/tooling/.oh-my-zsh && cd /home/tooling/.oh-my-zsh && \
    git -c init.defaultBranch=main init -q && \
    git fetch -q --depth 1 https://github.com/ohmyzsh/ohmyzsh ${OHMYZSH_COMMIT} && \
    git -c advice.detachedHead=false checkout -q FETCH_HEAD && \
    git clone -q --depth 1 --branch ${ZSH_AUTOSUGGESTIONS_VERSION} \
    https://github.com/zsh-users/zsh-autosuggestions custom/plugins/zsh-autosuggestions && \
    git clone -q --depth 1 --branch ${ZSH_SYNTAX_HIGHLIGHTING_VERSION} \
    https://github.com/zsh-users/zsh-syntax-highlighting custom/plugins/zsh-syntax-highlighting && \
    rm -rf .git custom/plugins/*/.git && cd / && \
    echo 'source /globals/zshrc' > /home/tooling/.zshrc && \
    chgrp -R 0 /home/tooling/.oh-my-zsh /home/tooling/.zshrc && \
    chmod -R g=u /home/tooling/.oh-my-zsh /home/tooling/.zshrc

ENV KUBECONFIG=/home/user/.kube/config
ENV LANG="en_US.UTF-8"
ENV STARSHIP_ENABLED="true"

# Files land with their final group/mode: a recursive chgrp/chmod over
# /home/tooling in a later layer would copy every binary into that layer again
COPY --chown=0:0 --chmod=664 starship.toml ${HOME}/.config/starship.toml
COPY --chown=0:0 --chmod=664 zshrc /globals/zshrc
COPY --chown=0:0 --chmod=664 .stow-local-ignore /home/tooling/
COPY --chown=0:0 --chmod=755 entrypoint.sh /
COPY --chown=0:0 --chmod=664 .copy-files /home/tooling/
COPY --chown=0:0 --chmod=775 url.sh /home/tooling/.local/bin/url


RUN useradd -u 1234 -G root -d /home/user --shell /bin/bash -m user && \
    touch /etc/subgid /etc/subuid  && \
    chmod g=u /etc/subgid /etc/subuid /etc/passwd  && \
    echo user:10000:65536 > /etc/subuid  && \
    echo user:10000:65536 > /etc/subgid && \
    echo 'export PATH="/home/tooling/.local/bin:$PATH"' >> ${GLOBALS_SHELLRC} && \
    echo 'export PATH="/home/user/.local/bin:$PATH"' >> ${GLOBALS_SHELLRC} && \
    echo 'export PATH="/checode/checode-linux-libc/ubi9/bin/remote-cli:$PATH"' >> ${GLOBALS_SHELLRC} && \
    echo '[ -f "/home/user/.bashrc_perso" ] && source /home/user/.bashrc_perso'  >> ${GLOBALS_BASHRC} && \
    chmod g=u /etc/passwd /etc/group && \
    # COPY --chmod=664 above also gave the .config it created mode 664: without x the
    # arbitrary UID cannot traverse it (starship: "Permission denied"), so set it explicitly
    chgrp 0 /home /home/tooling/.config && chmod g=u /home && chmod 775 /home/tooling/.config && \
    chgrp -R 0 /home/user && chmod -R g=u /home/user

ENV PATH="/home/user/.local/bin:$PATH"
ENV PATH="/home/tooling/.local/bin:$PATH"



USER 1234
RUN cp -f /home/tooling/.bashrc /home/user/.bashrc && \
    cp -f /home/tooling/.zshrc /home/user/.zshrc && \
    mkdir -p /home/user/.config && cp -f /home/tooling/.config/starship.toml /home/user/.config/starship.toml && \
    stow . -t /home/user/ -d /home/tooling/ --no-folding && \
    chgrp -R 0 /home/user && chmod -R g=u /home/user
ENV HOME=/home/user
WORKDIR /projects
# tini as PID 1: reaps orphaned zombies and forwards SIGTERM so the
# container stops promptly instead of waiting out the grace period
ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
CMD ["sleep","infinity"]