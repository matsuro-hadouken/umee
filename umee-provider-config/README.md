### Price Feeder Split Config [ Fri 2023-10-13 ]
```toml
This config only valid at this particular moment in time ^^
```

Contain 28 assets:

* AKT
* ATOM
* BNB
* CBETH
* CMST
* CRO
* DAI
* DOT
* ETH
* IST
* JUNO
* LUNA
* MARS
* MATIC
* NCT
* OSMO
* SOMM
* UMEE
* USDC
* USDT
* USK
* WAXL
* WBTC
* qATOM
* stATOM
* stJUNO
* stOSMO
* stkATOM

### Systemd

For the record `price-feeder.service` additionally provided.

Current configuration assume we are running feeder from $USER name `feeder` and absolute path to config folder is:
```
/home/feeder/umee-provider-config
```
Systemd config need to be adjusted accordingly:
```
Environment="PRICE_FEEDER_PASS=<my_password>"

User=feeder
Group=feeder

ExecStart=/path/to/price-feeder /home/feeder/umee-provider-config/price-feeder.toml ...
```
For `price-feeder.toml`
* set `config_dir = "/home/feeder/umee-provider-config"`
* edit ==>
```toml
[account]
address = "umee1..."
validator = "umeevaloper1..."
```
Assume we have dedicated keyring for user feeder and password:
```toml
[keyring]
backend = "os"
dir = "/home/feeder/.umee/"
pass = "my_password"
```
* adjust telemetry ...
```toml
[telemetry]
```
