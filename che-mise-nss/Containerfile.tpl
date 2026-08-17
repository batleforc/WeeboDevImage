FROM @@REGISTRY@@/che-min-mise:main
# @@BASE_CHE_MIN_MISE_IMAGE@@ -> ghcr.io/batleforc/weebodevimage/che-min-mise:main

LABEL org.opencontainers.image.authors="batleforc"
LABEL org.opencontainers.image.url="https://github.com/batleforc/WeeboDevImage/che-mise-nss"
LABEL org.opencontainers.image.source="https://github.com/batleforc/WeeboDevImage"
LABEL org.opencontainers.image.title="Che-Min-Mise-Nss"

USER 0

# Arbitrary-UID identity via nss_wrapper instead of a group-writable /etc/passwd.
#
# The inherited che-min-mise entrypoint auto-detects libnss_wrapper.so: when it
# is present, the current user is registered through NSS_WRAPPER_* + LD_PRELOAD
# rather than by appending to /etc/passwd. We then restore /etc/passwd and
# /etc/group to root:root 0644 (che-min-mise ships them group-writable for the
# legacy UDI flow), so they can no longer be edited to inject a fake root user.
#
# apt is purged afterwards (this image is a dead end, nothing derives from it):
# distro packages can no longer be installed, tools come from mise. dpkg and
# its status database are kept so `dpkg -l/-S` and CVE scanners keep working,
# but installing is disabled too: dpkg execs dpkg-deb to unpack archives, so
# removing dpkg-deb/dpkg-split breaks `dpkg -i` while queries stay intact, and
# `no-act` in dpkg.cfg turns any remaining dpkg action into a dry run.
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends libnss-wrapper && \
    rm -rf /var/lib/apt/lists/* && \
    dpkg --purge --force-remove-protected --force-depends apt && \
    rm -f /usr/bin/dpkg-deb /usr/bin/dpkg-split && \
    echo no-act >> /etc/dpkg/dpkg.cfg && \
    chown 0:0 /etc/passwd /etc/group && \
    chmod 0644 /etc/passwd /etc/group

USER 1234
WORKDIR /projects
