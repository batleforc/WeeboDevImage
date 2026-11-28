# Sourced by every shell (/globals/shellrc). The Che dashboard points the
# kubeconfig it injects at the ServiceAccount's ca.crt, which weebo-si's
# KubeArmor policy blocks: it shares the token's directory, a timestamped one
# no rule can carve out. Che's CA bundle, mounted in every workspace
# container, holds the cluster CA.
# shortcut: fixed when a shell starts, so a tool run before any terminal opens
# still sees the old path; move to a watcher if that bites.
_kc="${KUBECONFIG:-${HOME}/.kube/config}"
_ca=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
if [ -r "${_ca}" ] && grep -qs 'certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt' "${_kc}"; then
  sed -i "s|certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt|certificate-authority: ${_ca}|" "${_kc}"
fi
unset _kc _ca
