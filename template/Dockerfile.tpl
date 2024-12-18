FROM ghcr.io/batleforc/weebodevimage/che-base:main

LABEL org.opencontainers.image.url="batleforc/che-{{.Name}}"
LABEL org.opencontainers.image.title="Che-{{.FullName}}"
LABEL org.opencontainers.image.source="{{.SourceUrl}}"

ENV HOME=/home/tooling
USER 0

# START Infra Block


# END Infra Block

ENV STAR_NO="true"

# START User Block

# END User Block
USER 1234
ENV HOME=/home/user
RUN stow . -t /home/user -d /home/tooling --no-folding
RUN cp -f /home/tooling/.bashrc /home/user/.bashrc
WORKDIR /home/user
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["tail", "-f", "/dev/null"]