#!/usr/bin/env bash
# Usage: url [endpoint-name]
# Outputs the Eclipse Che public endpoint URL.
# Endpoint name defaults to "base" if omitted.
set -euo pipefail

USERNAME="${DEVWORKSPACE_NAMESPACE##*-}"
WORKSPACE="${DEVWORKSPACE_NAME:-}"
DASHBOARD_URL="${CHE_DASHBOARD_URL:-}"

[[ -z "$DEVWORKSPACE_NAMESPACE" ]] && { echo "Error: DEVWORKSPACE_NAMESPACE is not set" >&2; exit 1; }
[[ -z "$WORKSPACE"     ]] && { echo "Error: DEVWORKSPACE_NAME is not set"      >&2; exit 1; }
[[ -z "$DASHBOARD_URL" ]] && { echo "Error: CHE_DASHBOARD_URL is not set"      >&2; exit 1; }

# Extract domain from CHE_DASHBOARD_URL (e.g. https://cde.batleforc.fr/ -> cde.batleforc.fr)
DOMAIN="${DASHBOARD_URL#*://}"
DOMAIN="${DOMAIN%%/*}"

echo "https://${USERNAME}-${WORKSPACE}-${ENDPOINT_NAME}.${DOMAIN}/"
