#!/usr/bin/env bash
# Usage: url [endpoint-name]
# Outputs the Eclipse Che public endpoint URL.
# Endpoint name defaults to "base" if omitted.
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Usage: url [endpoint-name]

Outputs the Eclipse Che public endpoint URL for the current workspace.

Arguments:
  endpoint-name   Name of the endpoint to build the URL for (default: "base").
                  Can also be set via the ENDPOINT_NAME environment variable.

Options:
  -h, --help      Show this help message and exit.

Environment variables (must be set, usually provided by the workspace):
  DEVWORKSPACE_NAMESPACE   Used to derive the username (suffix after the last "-").
  DEVWORKSPACE_NAME        The workspace name.
  CHE_DASHBOARD_URL        Used to derive the domain.

Example:
  url            -> https://<user>-<workspace>-base.<domain>/
  url 8080-tcp   -> https://<user>-<workspace>-8080-tcp.<domain>/
EOF
  exit 0
fi

ENDPOINT_NAME="${1:-${ENDPOINT_NAME:-base}}"
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
