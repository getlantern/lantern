# Updating the embedded configuration

To update the embedded proxies as well as the global config, simply run: 

```
./genconfig.bash
```

That will generate a number of files, but **the only ones that matter are ../config/embeddedGlobal.go and ../config/embeddedProxies.go**, and the script will automatically add those files for you to manually commit. 

(Note: we used to upload the global configuration for the config server manually from here, but we've automated that and moved it to the lantern_aws project. Look there if you want to make any changes to the global configuration, other than masquerade updates. **In particular, if you want to make changes to things like the global proxied sites list downloaded from the config server, you have to do that [here](https://github.com/getlantern/lantern_aws/blob/master/salt/update_masquerades/original.txt)**)
