schemaVersion: 2.3.0
metadata:
  name: WeeboDevImageBaseSlim

components:
- name: tools
  container:
    image: @@REGISTRY@@/che-base-slim:main
    memoryLimit: 8Gi
    memoryRequest: 1Gi
    cpuLimit: "2"
    cpuRequest: "500m"
    mountSources: true
    endpoints:
    - name: base
      targetPort: 5437
      exposure: public
      protocol: https
      secure: true
    env:
    - name: ENV
      value: "dev-che"
    - name: "PORT"
      value: "5437"