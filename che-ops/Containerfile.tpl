FROM @@REGISTRY@@/che-base:main

LABEL org.opencontainers.image.url="batleforc/che-ops"
LABEL org.opencontainers.image.title="Che-OpsImage"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"

ENV HOME=/home/tooling
USER 0

## Set version target

ENV CLUSTERCTL_VERSION="@@OPS_CLUSTERCTL@@"
ENV TALOSCTL_VERSION="@@OPS_TALOSCTL@@"
ENV OPENTOFU_VERSION="@@OPS_OPENTOFU@@"
ENV ARGOCDCLI_VERSION="@@OPS_ARGOCD@@"
ENV UPDATECLI_VERSION="@@OPS_UPDATECLI@@"

## ArgoCD
RUN wget https://github.com/argoproj/argo-cd/releases/download/${ARGOCDCLI_VERSION}/argocd-linux-amd64 && \
  chmod +x argocd-linux-amd64 && \
  mv argocd-linux-amd64 /usr/local/bin/argocd

## Clusterctl
RUN wget https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-amd64 && \
    chmod +x clusterctl-linux-amd64 && \
    mv clusterctl-linux-amd64 /usr/local/bin/clusterctl

## Talosctl
RUN wget https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-amd64 && \
  chmod +x talosctl-linux-amd64 && \
  mv talosctl-linux-amd64 /usr/local/bin/talosctl

## Opentofu
RUN wget https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.tar.gz && \
    tar -xvf tofu_${OPENTOFU_VERSION}_linux_amd64.tar.gz && \
    mv tofu /usr/local/bin/tofu && \
    rm -rf tofu_${OPENTOFU_VERSION}_linux_amd64.tar.gz

## Add Wireguard
RUN apt update && apt install wireguard -y

## UpdateCLI
RUN wget https://github.com/updatecli/updatecli/releases/download/${UPDATECLI_VERSION}/updatecli_Linux_x86_64.tar.gz && \
    tar -xvf updatecli_Linux_x86_64.tar.gz && \
    mv updatecli /usr/local/bin/updatecli && \
    rm -rf updatecli_Linux_x86_64.tar.gz

USER 1234
RUN cp -f /home/tooling/.bashrc /home/user/.bashrc
RUN stow . -t /home/user -d /home/tooling --no-folding
ENV HOME=/home/user
WORKDIR /home/user
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["tail", "-f", "/dev/null"]
