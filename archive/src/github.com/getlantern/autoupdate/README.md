# Lantern Autoupdate

The `autoupdate` package provides [Lantern][1] with the ability to request,
download and apply software updates over the network with minimal interaction.
At this time, `autoupdate` relies on the [go-update][2] and the
[autoupdate-server][3] packages.

## General flow

![lanternautoupdates - general client](https://cloud.githubusercontent.com/assets/385670/6097030/736614c8-af72-11e4-932f-07f718c51673.png)

At some point on the Lantern application's lifetime, an independent process
will be created, this process will periodically send local information (using a
proxy, if available) to an update server that will compare client's data
against a list of releases. When applicable, the server will generate a binary
patch and send a reply to the client containing the URL of the appropriate
patch. The client will download and apply the patch to its executable file so
the new version is ready the next time Lantern starts.

### Update server

![lanternautoupdates - server process](https://cloud.githubusercontent.com/assets/385670/6097042/cb08d42c-af72-11e4-9ca4-d09af2fbb11b.png)

The update server holds a list of releases and waits for queries from clients.
Clients will send their own checksum and the server will compare that checksum
against the checksum of the latest release, if they don't match a binary diff
will be generated. This binary diff can be used by the client to patch itself.

### Download server

The update server may or may not be used as a download server. Clients will
pull binary diffs from this location, the actual patch's URL will be provided
by the update server.

### Client

![lanternautoupdates - auto update process](https://cloud.githubusercontent.com/assets/385670/6097031/755f89c6-af72-11e4-82ea-0c82f27160b2.png)

A client will compute the checksum of its executable file and will send it to
an update server periodically. When the update server replies with a special
message meaning that a new version is available, the client will download the
binary patch, apply it to a temporary file and check the signature, if the
signature is what the client expects, the original executable will be replaced
with the patched one.

[1]: https://getlantern.org/
[2]: https://github.com/inconshreveable/go-update
[3]: https://github.com/getlantern/autoupdate-server
