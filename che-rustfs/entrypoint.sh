#!/bin/bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

# rustfs aborts on a missing volume root instead of creating it
mkdir -p "${RUSTFS_VOLUMES}"

# S3 API on :9000, console on :9001; config via RUSTFS_* env vars
exec rustfs "${RUSTFS_VOLUMES}"
