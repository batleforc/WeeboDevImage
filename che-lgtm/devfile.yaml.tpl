schemaVersion: 2.3.0
metadata:
  name: WeeboDevImageLGTM

components:
- name: tools
  container:
    image: @@REGISTRY@@/che-min-mise:main
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
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://localhost:4318"
    - name: OTEL_EXPORTER_OTLP_PROTOCOL
      value: "http/protobuf"
- name: lgtm
  container:
    image: @@REGISTRY@@/che-lgtm:main
    memoryLimit: 3Gi
    memoryRequest: 1Gi
    cpuLimit: "2"
    cpuRequest: 250m
    mountSources: false
    endpoints:
    - name: grafana
      targetPort: 3000
      exposure: public
      protocol: https
      secure: true
    - name: otlp-grpc
      targetPort: 4317
      exposure: internal
      protocol: http
    - name: otlp-http
      targetPort: 4318
      exposure: internal
      protocol: http
