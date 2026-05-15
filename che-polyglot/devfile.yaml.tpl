schemaVersion: 2.3.0
metadata:
  name: WeeboDevImagePolyglot

components:
- name: tools
  container:
    image: @@REGISTRY@@/che-polyglot:main
    memoryLimit: 8Gi
    memoryRequest: 2Gi
    cpuLimit: "4"
    cpuRequest: "500m"
    mountSources: true
    endpoints:
    - name: polyglot
      targetPort: 5437
      exposure: public
      protocol: https
      secure: true
    env:
    - name: ENV
      value: "dev-che"
    - name: "PORT"
      value: "5437"
  attributes:
    pod-overrides:
      metadata:
        annotations:
          io.kubernetes.cri-o.Devices: "/dev/fuse,/dev/net/tun"
      spec:
        hostUsers: false
        securityContext:
          procMount: Unmasked

commands:
- id: mise-install
  exec:
    label: "Install mise tools"
    commandLine: "~/.local/bin/mise install --yes"
    component: tools
    workingDir: /home/user

events:
  postStart:
  - mise-install