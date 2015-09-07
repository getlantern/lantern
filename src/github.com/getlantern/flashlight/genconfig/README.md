# genconfig

**Generate the YAML file and embedded Go datastructures containing the network configuration for the Lantern client**


## How it works

Config generation currently follows this approach:

1. Build a *model*, a complete list of working chained servers, masquerades and proxied sites.

1. Fill the Go code templates (*.go), based on the model.

1. Fill the YAML template, based on the model. The YAML template already has filled in the LFS round-robin (flashlight servers for domain fronting).

## Using genconfig

### Managing masquerade hosts

The file domains.txt contains the list of masquerade hosts we use, and
blacklist.txt contains a list of blacklisted domains that we exclude even if
present in domains.txt.

To alter the list of domains or blacklist:

1. Edit [`domains.txt`](domains.txt) and/or [`blacklist.txt`](blacklist.txt)
2. `go run genconfig.go -domains domains.txt -blacklist blacklist.txt`.
3. Commit the changed [`masquerades.go`](masquerades.go) and [`cloud.yaml`](cloud.yaml) to git if you want.
4. Upload the configuration to Redis with [`cfg2redis.py`](cfg2redis.py), if desired.

### Managing proxied sites

Lists of proxied sites are expected to live as text files in a directory, one
domain per line.  You provide this directory to `genconfig` with the `-proxiedsites` argument.

### Managing chained proxies

The IPs, access tokens, and other details that clients need in order to
connect to the chained (that is, non-fronted) proxies we run are contained in
a JSON file that normally lives in `genconfig/fallbacks.json` and is fed to
`genconfig` with the optional `-fallbacks` argument.

You only need to concern yourself with this when the list of chained proxies
changes (e.g., when we launch or kill some server).  To learn how to regenerate
the `fallbacks.json` file in that case, see [the relevant
section](https://github.com/getlantern/lantern_aws#regenerating-flashlightgenconfigfallbackjson)
of the README of the lantern_aws project.

### Manually uploading servers to Redis

Although server queue is automatically managed **<Fill with link and explanation here>**, the [`cfg2redis.py`](cfg2redis.py) can be used to manually update the server queue in config-server. You can follow these steps to achieve that:

1. Make sure you have *REDISCLOUD_PRODUCTION_URL* set as an environment variable -- see https://github.com/getlantern/too-many-secrets/blob/master/lantern_aws/config_server.yaml#L2
1. Run ```./genconfig.bash```
1. Run ```./cfg2redis.py --global cloud.yaml -```
