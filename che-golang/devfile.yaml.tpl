schemaVersion: 2.2.0
metadata:
  name: WeeboDevImageGolang

components:
- name: tools
  container:
    image: @@REGISTRY@@/che-golang:main
    memoryLimit: 8Gi
    memoryRequest: 1Gi
    cpuLimit: "2"
    cpuRequest: "500m"
    mountSources: true
    endpoints:
    - name: golang
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