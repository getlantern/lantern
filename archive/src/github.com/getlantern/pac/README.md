# pac

[pac](https://github.com/getlantern/pac) is a simple Go library to toggle on and
off pac(proxy auto configuration) for Windows, Mac OS and Linux. It will extract
a helper tool and use it to actually chage pac.

```go
pac.EnsureHelperToolPresent(fullPath, prompt, iconFullPath)
pac.On(pacUrl string)
pac.Off()
```

See 'example/main.go' for detailed usage.

### Embedding pac-cmd

pac uses binaries from the [pac-cmd](https://github.com/getlantern/pac) project.

To embed the binaries for different platforms, use the `pac2go.sh` script. This
script takes care of code signing the Windows and OS X executables.

This script signs the Windows executable, which requires that
[osslsigncode](http://sourceforge.net/projects/osslsigncode/) utility be
installed. On OS X with homebrew, you can do this with
`brew install osslsigncode`.

You will also need to set the environment variables BNS_CERT and BNS_CERT_PASS
to point to [bns-cert.p12](https://github.com/getlantern/too-many-secrets/blob/master/bns_cert.p12)
and its [password](https://github.com/getlantern/too-many-secrets/blob/master/build-installers/env-vars.txt#L3)
so that the script can sign the Windows executable.

This script also signs the OS X executable, which requires you to install our 
OS X signing certificate, available
[here](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12).
The password is [here](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12.txt).