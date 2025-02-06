FROM sonarsource/sonar-scanner-cli:5

RUN apk add --no-cache \
    ca-certificates \
    gcc \
    musl-dev \
    openssl \
    openssl-dev \
    git \
    libgit2

## Install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash
RUN echo 'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"' >> ${HOME}/.bashrc
RUN echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ${HOME}/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ${HOME}/.bashrc
RUN . ${HOME}/.bashrc && nvm install ${NODE_VERSION} && nvm alias default ${NODE_VERSION} && nvm use default && nvm cache clear && npm install --global yarn && corepack enable pnpm
ENV VSCODE_NODEJS_RUNTIME_DIR=/home/tooling/.nvm/versions/node/v${NODE_VERSION}/bin
ENV PATH=/home/tooling/.nvm/versions/node/v${NODE_VERSION}/bin:$PATH