# Lantern state document and transport protocol specifications

Draft 0.1.0

Status: incomplete

## Introduction

Lantern's user interface is implemented as a web application, rendered inside
a browser embedded inside a native desktop application. This document describes
the specifications for the representation of the state the web frontend expects
to receive from the backend to be able to display a correctly behaving user
interface, as well as for the protocol for sending the state and updates to it.

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
subscription to the top-level channel `/sync`, and may request subscriptions
to additional channels like `/sync/viz`, `/sync/settings`, and `/sync/roster`.
Each channel corresponds to a section of the UI; updates to the state of each
section of UI are sent over the corresponding channel. The `/sync/viz` channel
carries state for the map visualization, the `/sync/settings` channel carries
state for the settings UI, and the `/sync/roster` channel carries state to
display the user's Google Talk contacts. The top-level `/sync` channel carries
global application state, and may additionally carry state for any of its
sub-channels by merging it into the top-level state object (explained below).


### Initial publication: Initializing the frontend model

When the bayeux server honors a client's subscription request to a given
channel, it should immediately publish a message to that channel with the
necessary state to initialize that portion of the model. So after processing
a subscription request for the top-level channel `/sync`, it should
immediately publish a message to that channel like

```json
{
  "path":"",
  "value":{
    "foo":"bar",
    ...
}
```

containing all the relevant state in the `value` field. The frontend will then
merge `value` into its `model` object, and all the views bound to the updated
fields will be updated automatically through AngularJS. The `path` value of
`""` indicates that `value` should be merged into `model` at the top level,
rather than into a nested object; if `path` were set to `"viz"`, then `value`
would instead be merged into `model.viz`.

After the merge, `model` will look like:

```json
{
  "foo":"bar",
  ...
}
```

After receiving a subscription request for a sub-channel such as `/sync/viz`,
the server should similarly publish an initial message to that channel
with all the state necessary for the visualization in the `viz` field, e.g.:

```json
{
  "path":"viz",
  "value":{
    "user":{
      "loc":{
        "lat":1234.56,
        "lon":1234.56
        ...
}
```

The frontend should then merge this into `model.viz`. So `model` will now look
like:

```json
{
  "foo":"bar",
  "viz":{
    "user":{
      "loc":{
        "lat":1234.56,
        "lon":1234.56
        ...
}
```

and any views with bindings into `model.viz` will get updated automatically
through AngularJS. The settings and roster channels behave similarly.

The channels are designed this way so that when the frontend no longer needs to
display the UI for a particular section (e.g. the user closes the "contacts"
UI), it can unsubscribe from the corresponding channel, and the backend can
avoid sending the no-longer-relevant updates to the frontend until they are
needed again, at which point the frontend will signal this by resubscribing.
For instance, if the backend processes a change to the user's roster, it need
not send any update to the frontend if it isn't subscribed to the
`/sync/roster` channel.

If desired, rather than sending a state update over e.g. the `/sync/viz`
sub-channel, the server can instead send it over the top-level `/sync`
channel, merging it into the `"viz"` field of a top-level object that can also
carry additional state in other fields, and the frontend will merge this all
into its `model` object in a single update. So multiple messages over several
sub-channels can alternatively be merged into a single message over the
top-level `/sync` channel, if it is ever preferable.


### Subsequent publications: Updating the frontend model

After initial state is published in full over a given channel, updates to the
state can be published a field at a time using the `path` variable at whatever
granularity is desired. For instance, here is a fine-grained update to
a deeply-nested field with an atomic `value` payload:

```json
{
  "path":"viz.user.loc.lat",
  "value":3456.78
}
```

And here is a coarser-grained update with a complex `value` payload:

```json
{
  "path":"viz.user.loc",
  "value":{
    "lat":3456.78,
    "lon":1234.56
    }
}
```

This flexibility can allow for a significant reduction in the amount of data
that must be serialized and deserialized to achieve a state synchronization.

Note however that while adding a field which is not yet present can be
represented in a very small message, removing a field can only be achieved by
sending the whole containing object minus the field to be removed. In this
case, setting the field to `null` may be a workable alternative, though we
may prefer to support something like:

```json
{
  "path":"foo.bar.baz",
  "delete":true
}
```

To update a field whose value is an array, of course a replacement array could
be sent in full, but because JavaScript arrays work like objects, an update to
just one of its elements could also be achieved simply by using the index as
the last component of the path. For instance,

```json
{
  "path":"settings.proxiedSitesList.25",
  "value":"twitter.com"
}
```

would cause `model.settings.proxiedSitesList[25]` to be set to `"twitter.com"`.
This requires the elements of an array to be maintained with the same ordering
on the frontend as the backend, but this should be true anyway for faithful
synchronization. For arrays that are maintained in sorted order, the efficiency
gain of this capability is much lower.


## State document specification

Every possible state determining the frontend's behavior can be represented
within the following state document, corresponding to the `model` object which
the backend maintains on the frontend through comet publications:
<table>
  <tr>
    <td><strong>lang</strong><br><em>string</em></td>
    <td>The system's language setting as a two-letter ISO 639-1 code.
      <br><br>Determines the language the UI is displayed in when the
      user's <strong>lang</strong> setting (under <strong>settings</strong>
      below) is not available (e.g. settings are locked).</td>
  </tr>
  <tr>
    <td><strong>setupScreen</strong><br>"welcome" | "signin" | "sysproxy" |
      "finished"
    </td>
    <td>If present, the UI will display the corresponding modal setup screen.
      <br><br><em>Replaces the boolean <code>initialSetupComplete</code>
        in the old UI, shifting the logic of determining which setup screen
        to display to the backend.</em>
    </td>
  </tr>
  <tr>
    <td><strong>connectivity</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>network</strong><br><em>boolean</em></td>
          <td>Whether the system is connected to the internet. If not, the
            frontend should indicate this and block user interaction which
            requires network connectivity.
          </td>
        </tr>
        <tr>
          <td><strong>gtalk</strong><br><em>boolean</em></td>
          <td>Whether we have signed in to Google Talk. If not, the frontend
            should indicate this and block user interaction which requires
            Google Talk connectivity.
          </td>
        </tr>
        <tr>
          <td><strong>peers</strong><br><em>number</em></td>
          <td>The number of peers we are connected to, <strong>including cloud
            proxies</strong> if in Get Mode.
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>version</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>app</strong><br><em>string</em></td>
          <td>The string the frontend should display as the Lantern
            version, e.g. <code>"0.98.2 beta"</code>
          </td>
        </tr>
        <tr>
          <td><strong>protocol</strong><br><em>array</em></td>
          <td>The major, minor, and patch revisions of the update protocol
            version, maintained
            <a href="http://semver.org/">semantically</a>, e.g.
            <code>[0, 1, 2]</code>.
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>bytesTransferred</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>current</strong><br><em>object</em></td>
          <td>
            <table>
              <tr>
                <td><strong>up</strong><br><em>number</em></td>
                <td>instantaneous upload rate in bytes per second.</td>
              </tr>
              <tr>
                <td><strong>dn</strong><br><em>number</em></td>
                <td>instantaneous download rate in bytes per second.</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td><strong>lifetime</strong><br><em>object</em></td>
          <td>
            <table>
              <tr>
                <td><strong>up</strong><br><em>number</em></td>
                <td>total number of bytes uploaded since first signin.</td>
              </tr>
              <tr>
                <td><strong>dn</strong><br><em>number</em></td>
                <td>total number of bytes downloaded since first signin.</td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>settings</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>state</strong><br>"locked" | "unlocked" | "corrupt"</td>
          <td>If "locked", the frontend will prompt the user for her Lantern
            password to unlock her encrypted settings. If "corrupt", the
            frontend will notify the user and block all user interaction
            besides quit and reset.
          </td>
        </tr>
        <tr>
          <td><strong>userid</strong><br><em>string</em></td>
          <td>The user's Google Talk/Lantern userid.</td>
        </tr>
        <tr>
          <td><strong>savePassword</strong><br><em>boolean</em></td>
          <td>Whether the user wants Lantern to securely store her Google
            Talk password.
          </td>
        </tr>
        <tr>
          <td><strong>passwordSaved</strong><br><em>boolean</em></td>
          <td>Whether the user's Google Talk password has been saved.</td>
        </tr>
        <tr>
          <td><strong>invites</strong><br><em>integer</em></td>
          <td>The number of private beta invites the user has remaining.</td>
        </tr>
        <tr>
          <td><strong>lang</strong><br><em>string</em></td>
          <td>The user's language setting as a two-letter ISO 639-1 code.</td>
        </tr>
        <tr>
          <td><strong>startAtLogin</strong><br><em>boolean</em></td>
          <td>Whether Lantern should start up automatically when the user logs
            into the system.
          </td>
        </tr>
        <tr>
          <td><strong>autoReport</strong><br><em>boolean</em></td>
          <td>Whether the user has enabled automatic error and usage reporting.
          </td>
        </tr>
        <tr>
          <td><strong>getMode</strong><br><em>boolean</em></td>
          <td>Whether we're in Get Mode.</td>
        </tr>
        <tr>
          <td><strong>proxyPort</strong><sup>1</sup><br><em>integer</em></td>
          <td>The port the Lantern http proxy is running on.</td>
        </tr>
        <tr>
          <td><strong>systemProxy</strong><sup>1</sup><br><em>boolean</em></td>
          <td>Whether to try to set Lantern as the system proxy.</td>
        </tr>
        <tr>
          <td><strong>proxyAllSites</strong><sup>1</sup><br><em>boolean</em></td>
          <td>Whether to proxy all sites or only those on
            <code>proxiedSitesList</code>.
          </td>
        </tr>
        <tr>
          <td><strong>proxiedSitesList</strong><sup>1</sup><br><em>string[]</em></td>
          <td>List of domains to proxy traffic to.<br><br><em>Replaces
            <code>whitelist</code> in the old UI.</em>
          </td>
        </tr>
      </table>
      <br><sup>1</sup> Only relevant in Get Mode
    </td>
  </tr>
  <tr>
    <td><strong>roster</strong><br><em>object[]</em></td>
    <td>
      <table>
        <tr>
          <td><em>TODO</em></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>viz</strong><br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><em>TODO</em></td>
        </tr>
      </table>
    </td>
  </tr>
</table>


<hr>

### Questions / Comments

* does cometd allow sub-channels under `/sync`?

* implement delete field via comet update? (see above)

* necessary to send revision number in each comet message? à la:

    > The `revision` field allows the frontend to ensure it's always merging
    in up-to-date state. It remembers the highest revision it's seen and
    ignores messages with a lower revision number.

    Would need to maintain separate revision for each channel because they're
    async

* should frontend refuse to connect to backend reporting incompatible version
    of update protocol?

* can we include the number of cloud proxies we can reach in the peer count?

* `proxiedSitesList` is displayed in sorted order, but can be stored out of
    order and sorted on the fly by angular to take advantage of the more
    efficient elementwise update capability.

    As for `roster`, the frontend doesn't ever modify or re-order it, it simply
    displays what the backend sends it in the same order, so the backend can
    determine how to send updates in whatever manner is most efficient.
