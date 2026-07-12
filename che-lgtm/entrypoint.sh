#!/usr/bin/env bash
set -uo pipefail

# Che/OpenShift may run us with an arbitrary UID (GID 0): give it a passwd entry
if ! whoami &>/dev/null && [ -w /etc/passwd ]; then
  echo "user:x:$(id -u):0:container user:${HOME}:/bin/bash" >> /etc/passwd
fi

# upstream launcher: grafana + prometheus + tempo + loki + pyroscope + otelcol
exec /otel-lgtm/run-all.sh
