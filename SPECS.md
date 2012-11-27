# Lantern state document and transport protocol specifications

Draft 0.0.1

Status: incomplete


## Introduction

Lantern's user interface is implemented as a web application, rendered inside
a browser embedded inside a native desktop application. This document describes
the specifications for the representation of the state the web frontend expects
to receive from the backend to be able to display a correctly behaving user
interface, the protocol for sending the state and updates to it, and the http
API the frontend expects to be able to call to notify the backend of user
interactions.

## State transport protocol

Lantern's [bayeux](http://cometd.org/documentation/bayeux/spec) server is
responsible for sending state updates to the frontend in real time as JSON
messages. When the Lantern UI is open, a bidirectional, real-time connection to
the bayeux server is made via JavaScript. Before the connection has been
established, or in case it is ever lost, the frontend should indicate it's
trying to connect to the Lantern backend and block any user interaction until
the connection is established. The bayeux client takes care of automatically
attempting to reconnect to the bayeux server if the connection is lost.


### Subscription

Upon successful connection to the bayeux server, the frontend will request
subscription to a channel named `/sync`.


### Initial publication: Initializing the frontend model

When the bayeux server honors a client's subscription request to the `/sync`
channel, it should immediately publish a message to that channel with the
necessary state to initialize the model like so:

```json
{
  "path":"",
  "value":{
    "foo":"bar",
    ...
}
```

All the relevant state is contained in the `value` field. The frontend will then
merge `value` into its `model` object, and all the views bound to the updated
fields will be updated. The `path` value of `""` indicates that `value` should
be merged into `model` at the top level, rather than into a nested object;
if `path` were instead set to `"foo"`, then `value` would instead be merged
into a `model.foo` object.

After the merge, `model` will look like:

```json
{
  "foo":"bar",
  ...
}
```


### Subsequent publications: Updating the frontend model

After initial state is published in full, updates to the state can be published
a field at a time using the `path` variable at whatever granularity is desired.
For instance, here is a fine-grained update to a deeply-nested field with an
atomic `value` payload:

```json
{
  "path":"foo.bar.baz",
  "value":3456.78
}
```

And here is a coarser-grained update:

```json
{
  "path":"foo.bar",
  "value":{
    "baz":3456.78,
    "bux":1234.56
    }
}
```

This flexibility can allow for a significant reduction in the amount of data
that must be serialized and deserialized to achieve a state synchronization.

Note however that while adding a field which is not yet present can be
represented in a very small message, removing a field can only be achieved by
sending the whole containing object minus the field to be removed. In this
case, setting the field to something falsy may be a workable alternative,
though we may prefer to support something like:

```json
{
  "path":"foo.bar.baz",
  "delete":true
}
```

To update a field whose value is an array, of course a replacement array could
be sent in full, but because JavaScript arrays are just objects, an update to
just one of its elements could also be achieved simply by using the index as
the last component of the path. For instance,

```json
{
  "path":"settings.proxiedSites.25",
  "value":"twitter.com"
}
```

would cause `model.settings.proxiedSites[25]` to be set to `"twitter.com"`.
This requires the elements of an array to be maintained with the same ordering
on the frontend as the backend, but this should be true anyway for faithful
synchronization. The frontend can efficiently present such lists in sorted
order via AngularJS without requiring them to be stored in sorted order.

<hr>


## State document specification

Every possible state determining the frontend's behavior can be represented
within the following state document, corresponding to the `model` object which
the backend maintains on the frontend through comet publications:
<table>
  <tr>
    <td><strong>mock</strong><br><em>object</em></td>
    <td>
      <table>
        <tr><td><strong>scenarios</strong><br><em>object</em></td>
          <td>mapping from http api endpoints (which trigger simulated scenarios
          when hit) to string descriptions</td></tr>
      </table>
      <small><strong>The <code>mock</code> field should only be sent by the
      mock backend.</strong></small>
    </td>
  </tr>
  <tr>
    <td><strong>system</strong><br><em>object</em></td>
    <td>
      <table>
        <tr><td><strong>os</strong><br>"windows" | "osx" | "ubuntu"</td>
            <td>operating system</td></tr>
        <tr><td><strong>lang</strong><br><em>string</em></td>
          <td>The system's language setting as a two-letter ISO 639-1 code.
          <br><br>Determines the language the UI is displayed in when the
          user's <strong>lang</strong> setting (under <strong>settings</strong>
          below) is not available (e.g. not yet set or settings are locked).
          </td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>location</strong><br><em>object</em></td>
    <td>
      <table>
        <tr><td><strong>country</strong><br>two-letter country code</td>
          <td>(last known) country connecting from (as reported by geoip lookup)</td></tr>
        <tr><td><strong>lat</strong><br><em>float</em></td>
          <td>(last known) latitude connecting from (as reported by geoip lookup)</td></tr>
        <tr><td><strong>lon</strong><br><em>float</em></td>
          <td>(last known) longitude connecting from (as reported by geoip lookup)</td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>countries</strong><br><em>object</em></td>
    <td>
      <table>
        <tr><td>"ir" | "cn" | ...</td>
          <td>
            <table>
              <tr><td><strong>censors</strong><br><em>boolean</em></td>
                <td>whether this country employs pervasive censorship,
                  as reported by (SOURCE) # XXX</td></tr>
            </table>
          </td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>version</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>installed</strong><br><em>object</em></td>
          <td>
            <table>
              <tr><td><strong>major</strong><br><em>int</em></td>
                <td>major version of the currently-running Lantern
                instance</td></tr>
              <tr><td><strong>minor</strong><br><em>int</em></td>
                <td>minor version of the currently-running Lantern
                instance</td></tr>
              <tr><td><strong>patch</strong><br><em>int</em></td>
                <td>patch version of the currently-running Lantern
                instance</td></tr>
              <tr><td><strong>tag</strong><br><em>string</em></td>
                <td>tag version of the currently-running Lantern
                instance</td></tr>
              <tr><td><strong>git</strong><br><em>string</em></td>
                <td>git revision of the currently-running Lantern
                instance</td></tr>
              <tr><td><strong>releaseDate</strong><br><em>date</em>
                <br>e.g. "2012-12-12"</td>
                <td>release date of the currently-running Lantern
                instance</td></tr>
              <tr><td><strong>stateSchema</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>major</strong><br><em>integer</em></td>
                      <td>state schema major version</td></tr>
                    <tr><td><strong>minor</strong><br><em>integer</em></td>
                      <td>state schema minor version</td></tr>
                    <tr><td><strong>patch</strong><br><em>integer</em></td>
                      <td>state schema patch version</td></tr>
                  </table><br><br>
                  <strong><small>The UI should display an 'unexpected state' error
                  if its required state schema version is incompatible with the
                  version published by the backend according to semantic
                  versioning (different major or minor)</small></strong>
                </td></tr>
              <tr><td><strong>httpApi</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>major</strong><br><em>integer</em></td>
                      <td>http api major version</td></tr>
                    <tr><td><strong>minor</strong><br><em>integer</em></td>
                      <td>http api minor version</td></tr>
                    <tr><td><strong>patch</strong><br><em>integer</em></td>
                      <td>http api patch version</td></tr>
                  </table><br><br>
                  <strong><small>The UI should display an 'unexpected state' error
                  if its required http api version is incompatible with the
                  version published by the backend according to semantic
                  versioning (different major or minor)</small></strong>
                </td></tr>
              <tr><td><strong>bayeuxProtocol</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>major</strong><br><em>integer</em></td>
                      <td>bayeux protocol major version</td></tr>
                    <tr><td><strong>minor</strong><br><em>integer</em></td>
                      <td>bayeux protocol minor version</td></tr>
                    <tr><td><strong>patch</strong><br><em>integer</em></td>
                      <td>bayeux protocol patch version</td></tr>
                  </table><br><br>
                  <strong><small>The UI should display an 'unexpected state' error
                  if its required bayeux protocol version is incompatible with
                  the version published by the backend according to semantic
                  versioning (different major or minor)</small></strong>
                </td></tr>
            </table>
          </td>
        </tr>
        <tr>
          <td><strong>latest</strong><br><em>object</em></td>
          <td><em>as in</em><code>version.installed</code><em>, but referring to the
          latest released version of Lantern rather than the currently-running
          version.</em></td>
        </tr>
        <tr>
          <td><strong>updateAvailable</strong><br><em>boolean</em></td>
          <td>Whether the latest available version of Lantern is newer than the
            currently-running version. The UI should prompt to update when
            true.</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>modal</strong><br>"settingsUnlock" |
      "settingsLoadFailure" | "welcome" | "giveModeForbidden" | "authorize" |
      "gtalkConnecting" | "gtalkUnreachable" |
      "notInvited" | "requestInvite" | "requestSent" | "firstInviteReceived" |
      "proxiedSites" | "systemProxy" | "inviteFriends" | "finished" |
      "settings" | "giveMode" | "about" | "updateAvailable" | ""
    </td>
    <td>Instructs the UI to display the corresponding modal dialog.
      A value of empty string means no modal dialog should be displayed.
    </td>
  </tr>
  <tr>
    <td><strong>setupComplete</strong><br><em>boolean</em></td>
    <td>Whether the user has completed Lantern setup</td>
  </tr>
  <tr>
    <td><strong>showVis</strong><br><em>boolean</em></td>
    <td>Whether to show the visualization</td>
  </tr>
  <tr>
    <td><strong>connectivity</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>internet</strong><br><em>boolean</em></td>
          <td>Whether the system has internet connectivity</td>
        </tr>
        <tr>
          <td><strong>ip</strong><br><em>string</em></td>
          <td>The system's public IP address, if available</td>
        </tr>
        <tr>
          <td><strong>gtalkOauthUrl</strong><br><em>url</em></td>
          <td>Url to use to request authorization to access the user's
            Google Talk account</td>
        </tr>
        <tr>
          <td><strong>gtalkAuthorized</strong><br><em>boolean</em></td>
          <td>Whether the user has authorized Lantern via Oauth to access
            her Google Talk account.</td>
        </tr>
        <tr>
          <td><strong>gtalk</strong><br>"notConnected" | "connecting" |
            "connected" </td>
          <td>Google Talk connectivity status. If notConnected, the frontend
            should indicate this and block user interaction which requires
            Google Talk connectivity.
          </td>
        </tr>
        <tr>
          <td><strong>peers</strong><br><em>object[]</em></td>
          <td>
            <table>
              <tr><td><strong>current</strong><br><em>string[]</em></td>
                  <td>list of peerids of currently connected peers</td></tr>
              <tr><td><strong>lifetime</strong><br><em>object[]</em></td>
                <td>
                  <table>
                    <tr><td><strong>userid</strong><br><em>string</em></td>
                      <td>identifier for the user that owns this peer.<br><br>
                      <strong><small>* Should be blank or omitted for users that
                      do not trust <code>settings.userid</code>
                      </small></strong></td></tr>
                    <tr><td><strong>peerid</strong><br><em>string</em></td>
                        <td>unique identifier for this peer<br><br>
                            <strong><small>* Needed because multiple peers with
                            the same userid are possible, since a user could be
                            running Lantern from several personal computers and/or
                            sponsoring cloud proxies</small></strong><br><br>
                            <strong><small>* Should not reveal identity of
                            associated user</small></strong></td></tr>
                    <tr><td><strong>type</strong><br>"desktop" | "laeproxy" | "lec2proxy"</td>
                        <td>type of Lantern client the peer is running<br><br>
                        <strong><small>* laeproxy and lec2proxy instances will have
                        userids associated with them via kaleidoscope</small>
                        </strong></td></tr>
                    <tr><td><strong>mode</strong><br>"give" | "get"</td>
                        <td>(last known) mode this peer is running in</td></tr>
                    <tr><td><strong>ip</strong><br><em>string</em></td>
                        <td>(last known) ip address of peer</td></tr>
                    <tr><td><strong>lat</strong><br><em>float</em></td>
                        <td>(last known) latitude of peer (as reported by geoip lookup)</td></tr>
                    <tr><td><strong>lon</strong><br><em>float</em></td>
                        <td>(last known) longitude of peer (as reported by geoip lookup)</td></tr>
                    <tr><td><strong>country</strong><br>two-letter code</td>
                        <td>(last known) country of peer (as reported by geoip lookup)</td></tr>
                    <tr><td><strong>bpsUp</strong><br><em>number</em></td>
                        <td>instantaneous upload rate to this peer</td></tr>
                    <tr><td><strong>bpsDn</strong><br><em>number</em></td>
                        <td>instantaneous download rate from this peer</td></tr>
                    <tr><td><strong>bpsTotal</strong><br><em>number</em></td>
                        <td>instantaneous upload+download rate with this peer</td></tr>
                    <tr><td><strong>bytesUp</strong><br><em>number</em></td>
                        <td>lifetime bytes uploaded to this peer</td></tr>
                    <tr><td><strong>bytesDn</strong><br><em>number</em></td>
                        <td>lifetime bytes downloaded from this peer</td></tr>
                    <tr><td><strong>bytesTotal</strong><br><em>number</em></td>
                        <td>lifetime bytes transferred with this peer</td></tr>
                  </table></td></tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>transfers</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>bpsUp</strong><br><em>number</em></td>
          <td>total instantaneous upload rate across all current peers</td>
        </tr>
        <tr>
          <td><strong>bpsDn</strong><br><em>number</em></td>
          <td>total instantaneous download rate across all current peers</td>
        </tr>
        <tr>
          <td><strong>bpsTotal</strong><br><em>number</em></td>
          <td>total instantaneous upload+download rate across all current peers</td>
        </tr>
        <tr>
          <td><strong>bytesUp</strong><br><em>number</em></td>
          <td>total number of bytes uploaded since first signin</td>
        </tr>
        <tr>
          <td><strong>bytesDn</strong><br><em>number</em></td>
          <td>total number of bytes downloaded since first signin</td>
        </tr>
        <tr>
          <td><strong>bytesTotal</strong><br><em>number</em></td>
          <td>total number of bytes uploaded+downloaded since first signin</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>roster</strong><br><em>object[]</em></td>
    <td>
      <table>
        <tr><td><strong>userid</strong><br><em>string</em></td>
          <td>Google Talk userid of roster contact</td></tr>
        <tr><td><strong>name</strong><br><em>string</em></td>
          <td>Name of roster contact, if available</td></tr>
        <tr><td><strong>avatarUrl</strong><br><em>string</em></td>
          <td>Avatar url of roster contact, if available</td></tr>
        <tr><td><strong>status</strong><br>"offline" | "away" | "idle" | "available"</td>
          <td>Contact's status</td></tr>
        <tr><td><strong>statusMessage</strong><br><em>string</em></td>
          <td>Contact's status message, if available</td></tr>
        <tr><td><strong>peers</strong><br><em>string[]</em></td>
          <td>list of all known Lantern peerids owned by this contact<br><br>
          <strong><small>* Used to tell if a roster contact is running
          Lantern</small></strong></td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>ninvites</strong><br><em>integer</em></td>
    <td>The number of Lantern invites user has remaining</td>
  </tr>
  <tr>
    <td><strong>nproxiedSitesMax</strong><br><em>integer</em></td>
    <td>The maximum number of configured proxied sites allowed</td>
  </tr>
  <tr>
    <td><strong>settings</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>userid</strong><br><em>string</em></td>
          <td>The user's Google Talk/Lantern userid.</td>
        </tr>
        </tr>
        <tr>
          <td><strong>lang</strong><br><em>string</em></td>
          <td>The user's language setting as a two-letter ISO 639-1 code.</td>
        </tr>
        <tr>
          <td><strong>autoStart</strong><br><em>boolean</em></td>
          <td>Whether Lantern should start up automatically when the user logs
            in to the system.
          </td>
        </tr>
        <tr>
          <td><strong>autoReport</strong><br><em>boolean</em></td>
          <td>Whether the user has enabled automatic error and usage reporting.
          </td>
        </tr>
        <tr>
          <td><strong>mode</strong><br>"give" | "get"</td>
          <td>Whether in give mode or get mode.</td>
        </tr>
        <tr>
          <td><strong>proxyPort</strong><a href="note-get-mode-only"><sup>1</sup></a><br><em>integer</em></td>
          <td>The port the Lantern http proxy is running on.</td>
        </tr>
        <tr>
          <td><strong>systemProxy</strong><a href="note-get-mode-only"><sup>1</sup></a><br><em>boolean</em></td>
          <td>Whether to try to set Lantern as the system proxy.</td>
        </tr>
        <tr>
          <td><strong>proxyAllSites</strong><a href="note-get-mode-only"><sup>1</sup></a><br><em>boolean</em></td>
          <td>Whether to proxy all sites or only those on
            <code>proxiedSites</code>.
          </td>
        </tr>
        <tr>
          <td><strong>proxiedSites</strong><a href="note-get-mode-only"><sup>1</sup></a><br><em>string[]</em></td>
          <td>List of domains to proxy traffic to.</td>
        </tr>
      </table>
      <br><small><a name="note-get-mode-only">1</a> Only present when in "get" mode</small>
    </td>
  </tr>
</table>

<hr>


## HTTP API


<table>
  <tr><td><strong>/reset</td>
    <td>restore Lantern to clean install state</strong></td></tr>
  <tr><td><strong>/changeSetting?<em>key</em>=<em>value</em></strong></td>
    <td>change setting indiciated by <em>key</em> to <em>value</em></td></tr>
  <tr><td><strong>/interaction?interaction=<em>key</em>[&amp;<em>param1</em>=<em>value1</em>[&amp;<em>param2</em>=<em>value2</em>[...]]]</strong></td>
    <td>Notify backend of user interaction corresponding to <em>key</em> and
      any associated parameters.</td></tr>
  <tr><td><strong>TODO...</strong></td>
    <td>For now please see <code>mock/http_api.js</code> in the code repository
        for a work-in-progress mock implementation.</td></tr>
</table>

<hr>


## Notes and Questions

* Frontend does not maintain any state outside of the state document, e.g. no
  longer tries to keep track of which modal to display when, just does as it's
  told via the `modal` field.

* Frontend never modifies the state document; only notifies the backend of
  user interactions via the `interaction` api and the backend responds by
  updating the state document (and in some cases setting a non-200 response
  code)

* Welcome modal now prompts for give/get mode choice

* Backend now checks country user is connecting from and only allows Get Mode
  if censoring

    * Hide Give Mode choice if censoring country detected or display
      giveModeForbidden modal?

* Password create now happens after welcome modal (on ubuntu)

* Oauth modal happens next.

    * If Google cannot be reached, user is given option
      to proceed in demonstration mode and is told that Lantern will keep trying to 
      connect in the background. Once backend is able to reach Google, it can set
      `modal` back to `authorize` to prompt user to try again.

    * If Google can be reached, Lantern should just wait until it has been
      given Gtalk authorization. Once it has, it should sign the user in to
      Google Talk.

    * No longer allow switching Google accounts after a successful
      sign in. Switching accounts should entail a full reset.

    * Backend should then check if the user has a Lantern invite. If not,
      it should notify the user via the `notInvited` modal and allow her to try
      using a different userid (e.g. go back to `authorize` modal) or request
      an invite via the `requestInvite` modal, and then proceed in
      demonstration mode. When the user gets an invite, backend should discover
      this and set modal to `firstInviteReceived`, and then take user back to
      the remaining setup modals.

* Next, get mode users are presented with the `proxiedSites` modal, introducing
  the concept that Lantern only proxies traffic to certain sites. `systemProxy`
  modal comes next, giving the user notice that an administrator password
  prompt may appear before Lantern can proceed. Next setup modal is
  `inviteFriends`.

* Give mode users are taken directly from `authorize` modal to `inviteFriends`.
  Backend should remember that the `proxiedSites` and `systemProxy` modals
  have never been completed, so that if the give mode user ever switches to
  get mode, the backend can take the user back there.

* `inviteFriends` is now a setup modal, to introduce the important concept of
  the trust network at the outset. User may not have any invites to give out
  yet, but will be told to expect to receive more as she continues to run
  Lantern.

* `advertiseLantern` setting?

* update connectivity.ip and location on reconnect to internet
