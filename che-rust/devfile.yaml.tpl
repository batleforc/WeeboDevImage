schemaVersion: 2.3.0
metadata:
  name: WeeboDevImageRust

components:
  - name: tools
    container:
      image: @@REGISTRY@@/che-rust:main
      memoryLimit: 8Gi
      memoryRequest: 1Gi
      mountSources: true
      endpoints:
        - name: rust
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
