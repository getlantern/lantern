# Updating the embedded configuration

We generally update the embedded configuration with each new Lantern release to update fronting domains and to include new embedded servers.

Make sure that any chained servers you want to bake in are populated in fallbacks.yaml.  You can generate this using the private lantern_aws/etc/fetchcfg.py, as follows: 
```
./fetchcfg.py sea > fallbacks.yaml
./fetchcfg.py etc >> fallbacks.yaml
```

Once this is done, copy the fallbacks.yaml to this directory and run ```./genconfig.bash```.

(Note: we used to upload the global configuration for the config server manually from here, but we've automated that and moved it to the lantern_aws project.  Look there if you want to make any changes to the global configuration, other than masquerade updates. **In particular, if you want to make changes to things like the global proxied sites list, you have to do that [here](https://github.com/getlantern/lantern_aws/blob/master/salt/update_masquerades/original.txt)**)
