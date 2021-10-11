### UMEE GRAFANA DASHBOARD

_This is very fast coded version made in rush, please report errors, contribution is highly appreciated_

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
* Check if metrics visible from Prometheus instance:
```bash
curl -s <your instance IP>:26660/metrics
```
* Point Prometheus to metrics end-point and restart, follow example, use your instance IP in case Prometheus is separated:
```bash
  - job_name: 'umee'
    static_configs:
    - targets: ['127.0.0.1:26660']
      labels:
        instance: umeevengers
```
* Import attached grafana dashboard json
* setup alerts, each alert have short description
* ask for help in Discord ( _is a mess currently going on, will do my best and help everyone as possible_ )
