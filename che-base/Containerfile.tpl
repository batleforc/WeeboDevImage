FROM @@REGISTRY@@/che-min:main

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-base"
LABEL org.opencontainers.image.title="Che-BaseImage"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"

ENV HELM_VERSION="@@BASE_TOOLS_HELM@@"
ENV TASKFILE_VERSION="@@BASE_TOOLS_TASKFILE@@"
ENV k9S_VERSION="@@BASE_TOOLS_K9S@@"
ENV KREW_VERSION="@@BASE_TOOLS_KREW@@"
ENV GITLEAKS_VERSION="@@BASE_TOOLS_GITLEAKS@@"
ENV KUBEDOCK_VERSION="@@BASE_TOOLS_KUBEDOCK@@"
ENV COCOGITTO_VERSION="@@BASE_TOOLS_COCOGITTO@@"
ENV YQ_VERSION="@@BASE_TOOLS_YQ@@"

ENV HOME=/home/tooling

USER 0

RUN mkdir -p ${GLOBALS_FOLDER} && touch ${GLOBALS_BASHRC} && \
  echo 'export PATH="${HOME}/.krew/bin:$PATH"' >> ${GLOBALS_BASHRC}

## Install Krew

ENV PATH="${HOME}/.krew/bin:$PATH"

RUN set -eux; \
  source ${GLOBALS_BASHRC} && \
  cd "$(mktemp -d)" && \
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/${KREW_VERSION}/krew-linux_amd64.tar.gz" && \
  tar -zxvf krew-linux_amd64.tar.gz && \
  ./"krew-linux_amd64" install krew && \
  rm -rf krew-linux_amd64.tar.gz krew-linux_amd64 &&\
  kubectl krew install ns &&\
  kubectl krew install ctx &&\
  kubectl krew install oidc-login &&\
  kubectl krew install resource-capacity

## Install jq/yq/zip and container tools
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  jq \
  zip \
  gnupg2 \
  vim \
  stow \
  iputils-ping \
  net-tools \
  libnode-dev \
  less \
  htop \
  podman \
  buildah \
  skopeo \
  fuse-overlayfs \
  libcap2-bin && \
  rm -rf /var/lib/apt/lists/* && \
  curl -fsSLo /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && \
  chmod +x /usr/local/bin/yq

## Install Helm + Taskfile + k9s + Cocogitto + GitLeaks
RUN tmpdir="$(mktemp -d)" && cd "${tmpdir}" && \
  curl -fsSLo helm.tar.gz https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
  tar -zxvf helm.tar.gz && \
  mv linux-amd64/helm /usr/local/bin/helm && \
  helm completion bash > /etc/bash_completion.d/helm && \
  echo 'source /etc/bash_completion.d/helm' >> ${GLOBALS_BASHRC} && \
  curl -fsSLo task.tar.gz https://github.com/go-task/task/releases/download/${TASKFILE_VERSION}/task_linux_amd64.tar.gz && \
  tar -xvf task.tar.gz && \
  mv task /usr/local/bin/task && \
  mv completion/bash/task.bash /etc/bash_completion.d/task && \
  echo 'source /etc/bash_completion.d/task' >> ${GLOBALS_BASHRC} && \
  curl -fsSLo k9s.tar.gz https://github.com/derailed/k9s/releases/download/${k9S_VERSION}/k9s_Linux_amd64.tar.gz && \
  tar -xvf k9s.tar.gz && \
  mv k9s /usr/local/bin/k9s && \
  curl -fsSLo cog.tar.gz https://github.com/cocogitto/cocogitto/releases/download/${COCOGITTO_VERSION}/cocogitto-${COCOGITTO_VERSION}-x86_64-unknown-linux-musl.tar.gz && \
  tar -xvf cog.tar.gz && \
  mv x86_64-unknown-linux-musl/cog /usr/local/bin/cog && \
  curl -fsSLo gitleaks.tar.gz https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz && \
  tar -xvf gitleaks.tar.gz && \
  mv gitleaks /usr/local/bin/gitleaks && \
  cd / && rm -rf "${tmpdir}"

## Install Gnupg aliases + Starship Shell Prompt
RUN echo 'export GPG_TTY=$(tty)' >> ${GLOBALS_BASHRC} && \
  echo 'alias load-priv="gpg --import /etc/gpgkey/keypriv.asc"' >> ${GLOBALS_BASHRC} && \
  echo 'alias load-pub="gpg --import /etc/gpgkey/keypub.asc"' >> ${GLOBALS_BASHRC} && \
  curl -sS https://starship.rs/install.sh | sh -s -- -y && \
  echo '[ $STAR_NO != "false" ] && eval "$(starship init bash)" ' >> ${GLOBALS_BASHRC}
ENV STAR_NO="true"
COPY starship.toml ${HOME}/.config/starship.toml

ENV _BUILDAH_STARTED_IN_USERNS="" BUILDAH_ISOLATION=chroot

## Nested container support: use fuse-overlayfs overlay driver instead of vfs
RUN mkdir -p "${HOME}"/.config/containers
COPY --chown=0:0 containers.conf "${HOME}"/.config/containers/containers.conf

## subuid/subgid writable by group; newuidmap/newgidmap need setuid/setgid caps for user namespaces
RUN chown -R 10001 "${HOME}"/.config && \
  touch /etc/subgid /etc/subuid && \
  chmod g=u /etc/subgid /etc/subuid /etc/passwd /etc/group && \
  setcap cap_setuid+ep /usr/bin/newuidmap && \
  setcap cap_setgid+ep /usr/bin/newgidmap

ENV KUBECONFIG=/home/user/.kube/config
RUN curl -fsSL https://github.com/joyrex2001/kubedock/releases/download/${KUBEDOCK_VERSION}/kubedock_linux_x86_64.tar.gz | \
  tar -C /usr/local/bin -xz --no-same-owner \
  && chmod +x /usr/local/bin/kubedock
COPY --chown=0:0 kubedock_setup.sh /usr/local/bin/kubedock_setup

ENV PODMAN_WRAPPER_PATH=/usr/bin/podman.wrapper
ENV ORIGINAL_PODMAN_PATH=/usr/bin/podman.orig
COPY --chown=0:0 podman-wrapper.sh "${PODMAN_WRAPPER_PATH}"

## Move podman + add buildctl
RUN mv /usr/bin/podman "${ORIGINAL_PODMAN_PATH}"

COPY --chown=0:0 .stow-local-ignore /home/tooling/
COPY --chown=0:0 entrypoint.sh /

## https://github.com/devfile/developer-images/blob/main/universal/ubi8/entrypoint.sh

RUN chgrp -R 0 /home/tooling && chmod -R g=u /home/tooling && \
  mkdir -p /home/user && ls /home && stow . -t /home/user/ -d /home/tooling/ --no-folding && \
  chgrp -R 0 /home && chmod -R g=u /etc/passwd /etc/group /home && \
  chmod +x /entrypoint.sh

USER 1234
RUN cp -f /home/tooling/.bashrc /home/user/.bashrc && \
  stow . -t /home/user/ -d /home/tooling/ --no-folding
ENV HOME=/home/user
WORKDIR /projects
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["tail", "-f", "/dev/null"]
