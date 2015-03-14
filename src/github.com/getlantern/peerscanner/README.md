# peerscanner - register flashlight peer and fallback servers

peerscanner is a HTTP-based service for registering and unregistering flashlight
servers so they can be used by the flashlight clients that run in Lantern
installations when in get mode.

Pedantic note for the fastidious: for agility of exposition we say
"flashlight server" to refer loosely to the machine where the flashlight server
is running.  Currently, the calls described below are made not by the flashlight
program itself but by the Lantern client that is controlling it.

## Operation

flashlight servers call a peerscanner endpoint periodically to advertise their
availability and up-to-date contact details.  If they have a chance, they also
inform peerdnsreg when they become unavailable.  Otherwise, peerdnsreg will
automatically unregister a server from which it hasn't received updates for too
long.

### Registering

A flashlight server registers itself by making a POST request with the
`/register` path.  The request parameters for this call are:

- `name`: a string identifier that is not equal to that of any other machine registering in peerdnsreg. It must be a valid subdomain name, *and* a valid [VCL](https://www.varnish-cache.org/docs/3.0/reference/vcl.html) identifier when prepended `f_`.  To be on the safe side, use only ASCII digits and lowercase letters.  Lantern peer clients use their `instanceId`, which meets these conditions.

- `port`: the port where this flashlight server can be reached from external clients (so, if the server is port mapped in a NAT, this would be the external port).

### Heartbeat

peerscanner will periodically test peers to see if it can proxy through them and
remove/add them to DNS as necessary.

### Unregistration

If it has a chance, a flashlight server will announce that it is becoming
unavailable by making a POST request with path `/unregister`.  The only
parameter is the `name` it provided back when it registered.

## Deploying

peerscanner is deployed to Digital Ocean using the peerscanner salt
configuration.

## Installing for local testing

You need to set some environment variables to connect to CloudFlare.  See
[envvars.bash](https://github.com/getlantern/too-few-secrets/blob/master/envvars.bash).

## Duplicate Checking

The program in dupecheck can be used to check the current CloudFlare DNS for
duplicates. `CFL_ID=<username> CFL_KEY=<api key> go run dupecheck.go`.
