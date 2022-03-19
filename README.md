### UMEE GRAFANA DASHBOARD

* Grafana version: v8.3.3 [ upgrade ! ]
* Requirement: node-exporter _( otherwise hardware data will not be available )_
* Enable prometheus metrics in $HOME/.umee/config/config.toml

```bash
[instrumentation]
prometheus = true
```
* By default tendermint serve metrics at port 26660, can be adjusted with:
```bash
prometheus_listen_addr = ":26660"
```
* Allow metrics port in firewal, use tunnels, subnets or prefered method.
* Publicly expose Prometheus metrics is bad idea, don't do this !
* Check if metrics visible from Prometheus instance by:
```bash
curl -s <UMEE node IP here>:26660/metrics
```
* Point Prometheus to metrics end-point and restart, follow example, use your instance IP in case Prometheus is separated:
```bash
  - job_name: 'umee_tendermint'
    static_configs:
    - targets: ['127.0.0.1:26660']
      labels:
        alias: 'umee_tendermint'
        instance: umee_server_x
```
* add node_exporter:
```bash
  - job_name: 'umee_hardware'
    static_configs:
    - targets: ['127.0.0.1:12345']
      labels:
        alias: 'umee_server'
        instance: umee_server_x
```
* Import attached grafana dashboard json
* setup alerts, each alert have short description
* ask for help in Discord

### AUTOSTAKE SERVICE _( used in test net, only works with "test" keyring )_

Example: _autostake.service_

```bash
[Unit]
Description=AUTOSTAKE SERVICE
After=network-online.target

[Service]

Type=simple

User=umee
Group=umee

ExecStart=/path/to/autostake.sh

Restart=on-failure
RestartSec=60

KillMode=process

[Install]

WantedBy=multi-user.target
```
