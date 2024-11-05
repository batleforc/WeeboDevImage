FROM {{.BaseImage}}

LABEL org.opencontainers.image.url="batleforc/che-node"
LABEL org.opencontainers.image.title="Che-Node"
LABEL org.opencontainers.image.source="batleforc/che-node"

ENV HOME=/home/tooling
USER 0

# START Infra Block

# TODO: Add Nginx

# END Infra Block

ENV STAR_NO="true"

# START User Block

# END User Block
USER 1234
ENV HOME=/home/user
RUN stow . -t .home/user -d /home/tooling --no-folding
RUN cp -f /home/tooling/.bashrc /home/user/.bashrc
WORKDIR /home/user
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["tail", "-f", "/dev/null"]