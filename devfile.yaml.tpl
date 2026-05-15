schemaVersion: 2.3.0
metadata:
  name: WeeboDevImage
  language: golang
  version: 1.0.0

components:
- name: tools
  container:
    image: @@REGISTRY@@/che-golang:main
    memoryLimit: 2Gi
    mountSources: true
- name: devtool
  container:
    image: buildpack-deps:bookworm
    memoryLimit: 1Gi
    mountSources: false
    command: ['tail']
    args: ['-f', '/dev/null']
