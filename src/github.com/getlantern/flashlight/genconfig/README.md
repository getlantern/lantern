# genconfig

**Generate the YAML file and embedded Go datastructures containing the network configuration for the Lantern client**


## How it works

Config generation currently follows this approach:

1. Build a *model*, a complete list of working chained servers, masquerades and proxied sites.

1. Fill the Go code templates (*.go), based on the model.

1. Fill the YAML template, based on the model. The YAML template already has filled in the LFS round-robin (flashlight servers for domain fronting).

## Using genconfig

### Setup

You need the s3cmd tool installed and set up.  To install on Ubuntu:

```bash
sudo apt-get install s3cmd
```

On OS X:

```bash
brew install s3cmd
```

And then run `s3cmd --configure` and follow the on-screen instructions.  You
can get AWS credentials that are good for uploading to S3 in
[too-many-secrets/lantern_aws/aws_credential](https://github.com/getlantern/too-many-secrets/blob/master/lantern_aws/aws_credential).

### Managing masquerade hosts

The file domains.txt contains the list of masquerade hosts we use, and
blacklist.txt contains a list of blacklisted domains that we exclude even if
present in domains.txt.

To alter the list of domains or blacklist:

1. Edit [`domains.txt`](genconfig/domains.txt) and/or [`blacklist.txt`](genconfig/blacklist.txt)
2. `go run genconfig.go -domains domains.txt -blacklist blacklist.txt`.
3. Commit the changed [`masquerades.go`](config/masquerades.go) and [`cloud.yaml`](genconfig/cloud.yaml) to git if you want.
4. *[Deprecated: we are not doing it any more]* Upload cloud.yaml to s3 using [`udpateyaml.bash`](genconfig/updateyaml.bash) if you want.

### Managing proxied sites

Lists of proxied sites are expected to live as text files in a directory, one
domain per line.  You provide this directory to `genconfig` with the `-proxiedsites` argument.

### Managing chained proxies

The IPs, access tokens, and other details that clients need in order to
connect to the chained (that is, non-fronted) proxies we run are contained in
a JSON file that normally lives in `genconfig/fallbacks.json` and is fed to
`genconfig` with the optional `-fallbacks` argument.

You only to concern yourself with this when the list of chained proxies
changes (e.g., when we launch or kill some server).  To learn how to reenerate
the `fallbacks.json` file in that case, see [the relevant
section](https://github.com/getlantern/lantern_aws#regenerating-flashlightgenconfigfallbackjson)
of the README of the lantern_aws project.

### Uploading to Redis

To add a bunch of servers to the queue of a datacenter, so they'll get pulled by the config server as necessary,

- Compile a fallbacks.json that only includes the given servers.  The quickest way to do this would be to generate the fallbacks.json with a prefix that only includes these servers.

- Generate a cloud.yaml from this fallbacks.json, as explained above.

- In the `genconfig` directory, run `./cfg2redis.py cloud.yaml <dc>`, where `<dc>` is the datacenter where the servers are located.  Current values are 'doams3' for the Digital Ocean Amsterdam 3 datacenter, and 'vltok1' for the Vulture Tokyo datacenter.  Add the `--dc` option if you want to upload the datacenter configuration too (e.g., if this is a new datacenter), but of course make sure the cloud.yaml contains the right configuration for that datacenter (e.g. the right fronted round robin(s)).

The cfg2redis has some prerequisites.  Just try it and it will tell you how to fulfill any missing ones.

If you *only* want to update the datacenter configuration you may:

1. Make sure you have *REDISCLOUD_PRODUCTION_URL* set as an environment variable -- see https://github.com/getlantern/too-many-secrets/blob/master/lantern_aws/config_server.yaml#L2
1. Run ```./genconfig.bash```
1. Run ```./cfg2redis.py --global cloud.yaml -```
