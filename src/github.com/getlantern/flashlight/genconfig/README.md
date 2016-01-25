# Updating the global configuration

We generally update the global configuration at least with each new Lantern release to update fronting domains and to include new embedded servers. It is also possible to do so independently from a client release, in which case you would simply skip generating new custom chained servers.

1. Make sure you have REDISCLOUD_PRODUCTION_URL set as an environment variable -- see https://github.com/getlantern/too-many-secrets/blob/master/lantern_aws/config_server.yaml#L2
1. If you want to embed custom chained servers (if you are releasing a client), make sure to have them populated in fallbacks.yaml and generated using the private lantern_aws/etc/fetchcfg.py. You can do this as follows: 
```
./fetchcfg.py vltok1 > fallbacks.yaml
./fetchcfg.py >> fallbacks.yaml
```
1. Run ```./genconfig.bash```
1. Run ```./cfg2redis.py --global cloud.yaml -```
