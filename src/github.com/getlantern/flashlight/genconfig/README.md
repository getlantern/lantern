# Updating the global configuration

1. Make sure you have REDISCLOUD_PRODUCTION_URL set as an environment variable -- see https://github.com/getlantern/too-many-secrets/blob/master/lantern_aws/config_server.yaml#L2
1. Run ```./genconfig.bash```
1. Run ```./cfg2redis.py --global cloud.yaml -```
