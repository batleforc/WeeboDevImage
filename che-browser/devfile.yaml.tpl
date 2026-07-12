schemaVersion: 2.3.0
metadata:
  name: WeeboDevImageBrowser

components:
- name: browser
  container:
    image: @@REGISTRY@@/che-browser:main
    memoryLimit: 3Gi
    memoryRequest: 1Gi
    cpuLimit: "2"
    cpuRequest: 500m
    mountSources: false
    endpoints:
    - name: novnc
      targetPort: 6080
      exposure: public
      protocol: https
      secure: true
    - name: cdp
      targetPort: 9222
      exposure: internal
      protocol: http
    - name: webdriver
      targetPort: 9515
      exposure: internal
      protocol: http
