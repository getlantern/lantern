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
subscription to a channel named `/sync`. This is the channel over which the
frontend receives updates to its (initially empty) model object from the
backend.


### State updates

When the bayeux server honors a client's subscription request to the `/sync`
channel, it should immediately publish a [JSON
PATCH](https://datatracker.ietf.org/doc/draft-ietf-appsawg-json-patch/) to the
channel with the necessary state to populate the model:

```json
[{
  "op": "replace",
  "path": "",
  "value": {
    "system": {
      "os": "...",
      ...
    },
    ...
  }
}]
```

After initial state is published in full, updates to the state can likewise be
published using JSON PATCH, e.g.

```json
[{
  "op": "add",
  "path": "/friends/pending/-",
  "value": {
    "email": "user@example.com"
  }
},{
  "op": "replace",
  "path": "/ninvites",
  "value": 0
}]
```

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
          <td>set of available scenarios the mock backend can
          simulate for testing</td></tr>
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
        <tr><td><strong>version</strong><br>"10.7.5" | "12.04" | ...</td>
            <td>os version</td></tr>
        <tr><td><strong>arch</strong><br>"x86" | "x86_64" | ...</td>
            <td>architecture</td></tr>
        <tr><td><strong>processor</strong><br>"1.8 GHz Intel Core i7" | ...</td>
            <td>processor</td></tr>
        <tr><td><strong>memory</strong><br>"4 GB 1333 MHz DDR3" | ...</td>
            <td>memory</td></tr>
        <tr><td><strong>bytesFree</strong><br>int</td>
            <td>available bytes on the disk Lantern writes to</td></tr>
        <tr><td><strong>graphics</strong><br>"Intel HD Graphics 3000 384 MB" | ...</td>
            <td>graphics</td></tr>
        <tr><td><strong>displays</strong><br>[[1280, 1024]] | ...</td>
            <td>list of [pixel width, pixel height] pairs for each
            display</td></tr>
        <tr><td><strong>java</strong><br>"1.7.0_33" | ...</td>
            <td>java version</td></tr>
        <tr><td><strong>chrome</strong><br>"25.0.1364.5" | ...</td>
            <td>chrome version</td></tr>
        <tr><td><strong>lang</strong><br>"en" | "es" | ...</td>
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
        <tr><td><strong>country</strong><br>ISO 3166-1 alpha-2 country code</td>
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
        <tr><td><strong>&lt;COUNTRY-CODE&gt;</strong><br>"AD" | "AE" | "AF" | ...</td>
          <td>
            <table>
              <tr><td><strong>censors</strong><br><em>boolean</em></td>
                <td>whether this country employs pervasive censorship,
                  as reported by <em>&lt;LIVE SOURCE WHICH IS KEPT
                  UP-TO-DATE&gt;</em> <strong># XXX TODO</strong></td></tr>
              <tr><td><strong>bps</strong><br><em>int</em></td>
                <td>Total number of bytes per second being transferred right
                  now by all online peers in this country.</td>
              <tr><td><strong>bytesEver</strong><br><em>int</em></td>
                <td>Total number of bytes ever transferred by peers in this
                  country.</td>
              <tr><td><strong>nusers</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>online</strong><br><em>int</em></td>
                      <td>Number of users online now in this country.</td></tr>
                    <tr><td><strong>ever</strong><br><em>int</em></td>
                      <td>Number of users that ever connected in this country.</td></tr>
                  </table>
                </td></tr>
              <tr><td><strong>npeers</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>online</strong><br><em>object</em></td>
                      <td>
                        <table>
                          <tr><td><strong>give</strong><br><em>int</em></td>
                            <td>Number of Give Mode peers online now in this
                              country.</td></tr>
                          <tr><td><strong>get</strong><br><em>int</em></td>
                            <td>Number of Get Mode peers online now in this
                              country.</td></tr>
                          <tr><td><strong>giveGet</strong><br><em>int</em></td>
                            <td>Number of Give and Get Mode peers online now
                              in this country.</td></tr>
                        </table>
                      </td></tr>
                    <tr><td><strong>ever</strong><br><em>object</em></td>
                      <td>
                        <table>
                          <tr><td><strong>give</strong><br><em>int</em></td>
                            <td>Number of Give Mode peers ever to connect in
                              this country.</td></tr>
                          <tr><td><strong>get</strong><br><em>int</em></td>
                            <td>Number of Get Mode peers ever to connect in
                              this country.</td></tr>
                          <tr><td><strong>giveGet</strong><br><em>int</em></td>
                            <td>Number of Give and Get Mode users ever to
                              connect in this country.</td></tr>
                        </table>
                      </td></tr>
                  </table>
                </td></tr>
            </table>
          </td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>global</strong><br><em>object</em></td>
    <td>
      <table>
        <tr><td><strong>nusers</strong><br><em>object</em></td>
          <td>
            <table>
              <tr><td><strong>online</strong><br><em>int</em></td>
                <td>Total number of users online now worldwide.</td></tr>
              <tr><td><strong>ever</strong><br><em>int</em></td>
                <td>Total number of users ever worldwide.</td></tr>
            </table>
          </td>
        </tr>
        <tr><td><strong>npeers</strong><br><em>object</em></td>
          <td>
            <table>
              <tr><td><strong>online</strong><br><em>object</em></td>
                  <td>
                    <table>
                      <tr><td><strong>give</strong><br><em>int</em></td>
                        <td>Number of Give Mode peers online now worldwide.</td></tr>
                      <tr><td><strong>get</strong><br><em>int</em></td>
                        <td>Number of Get Mode peers online now worldwide.</td></tr>
                      <tr><td><strong>giveGet</strong><br><em>int</em></td>
                        <td>Number of Give and Get Mode peers online now
                          worldwide.</td></tr>
                    </table>
                  </td>
              </tr>
              <tr><td><strong>ever</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>give</strong><br><em>int</em></td>
                      <td>Number of Give Mode peers ever to connect worldwide.</td></tr>
                    <tr><td><strong>get</strong><br><em>int</em></td>
                      <td>Number of Get Mode peers ever to connect worldwide.</td></tr>
                    <tr><td><strong>giveGet</strong><br><em>int</em></td>
                      <td>Number of Give and Get Mode users ever to
                        connect worldwide.</td></tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr><td><strong>bps</strong><br><em>int</em></td>
          <td>Total bytes per second being transferred worldwide right now.</td></tr>
        <tr><td><strong>bytesEver</strong><br><em>int</em></td>
          <td>Total bytes transferred worldwide ever.</td></tr>
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
              <tr><td><strong>installerUrl</strong><br><em>url</em>
                <td>installer url for the user's platform</td></tr>
              <tr><td><strong>installerSHA1</strong><br><em>string</em>
                <td>SHA-1 of the installer for the user's platform</td></tr>
              <tr><td><strong>changes</strong><br><em>object[]</em></td>
                <td>list of changes in this version.<br><br>
                    <strong>XXX use a "what's changed" link instead, which could
                    just point to a blog post or github compare view?</td>
              <tr><td><strong>modelSchema</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>major</strong><br><em>int</em></td>
                      <td>state schema major version</td></tr>
                    <tr><td><strong>minor</strong><br><em>int</em></td>
                      <td>state schema minor version</td></tr>
                    <tr><td><strong>patch</strong><br><em>int</em></td>
                      <td>state schema patch version</td></tr>
                  </table><br><br>
                  <strong><small>The UI should display an 'unexpected state' error
                  if its required model schema version is incompatible with the
                  version published by the backend according to semantic
                  versioning (different major or minor)</small></strong>
                </td></tr>
              <tr><td><strong>api</strong><br><em>object</em></td>
                <td>
                  <table>
                    <tr><td><strong>major</strong><br><em>int</em></td>
                      <td>api major version</td></tr>
                    <tr><td><strong>minor</strong><br><em>int</em></td>
                      <td>api minor version</td></tr>
                    <tr><td><strong>patch</strong><br><em>int</em></td>
                      <td>api patch version</td></tr>
                  </table><br><br>
                  <strong><small>The UI should display an 'unexpected state' error
                  if its required api version is incompatible with the
                  version published by the backend according to semantic
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
    <td><strong>modal</strong><br>
      "settingsLoadFailure" | "welcome" | "giveModeForbidden" | "authorize" |
      "gtalkConnecting" | "gtalkUnreachable" | "contact" |
      "notInvited" | "requestInvite" | "requestSent" | "firstInviteReceived" |
      "proxiedSites" | "systemProxy" | "lanternFriends" | "finished" |
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
          <td><strong>gtalkAuthorized</strong><br><em>boolean</em></td>
          <td>Whether the user has authorized Lantern via Oauth to access
            her Google Talk account.</td>
        </tr>
        <tr>
          <td><strong>gtalkOauthUrl</strong><br><em>string</em></td>
          <td>The url to open to request Oauth access to the user's
            Google Talk account.</td>
        </tr>
        <tr>
          <td><strong>lanternController</strong><br><em>boolean</em></td>
          <td>Whether the backend has heard back yet from Lantern Controller in
              response to a "does this user have Lantern access" query.
              Used along with <code>gtalk == "connecting"</code> to determine
              whether to show a "signing in to Lantern" spinner.<br>
              <strong>XXX Replace this with a general-purpose "showSpinner"
              field that could be used in other places.</strong>
          </td>
        </tr>
        <tr>
          <td><strong>peerid</strong><br><em>string</em></td>
          <td>The peerid of this user.</td>
        </tr>
        <tr>
          <td><strong>invited</strong><br><em>boolean</em></td>
          <td>Whether the user has been invited to Lantern.</td>
        </tr>
        <tr>
          <td><strong>gtalk</strong><br>"notConnected" | "connecting" |
            "connected" </td>
          <td>Google Talk connectivity status. If notConnected, the frontend
            should indicate this and block user interaction which requires
            Google Talk connectivity.
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>peers</strong><br><em>object[]</em></td>
    <td>
      List of all peers we've ever connected to.
      <table>
        <tr><td><strong>peerid</strong><br><em>string</em></td>
            <td>unique identifier for this peer<br><br>
                <strong><small>* Needed because multiple peers for
                the same user are possible, since a user could be
                running Lantern from several personal computers and/or
                sponsoring cloud proxies</small></strong><br><br>
                <strong><small>* Should not reveal identity of
                associated user</small></strong></td></tr>
        <tr><td><strong>rosterEntry</strong><br><em>object</em></td>
          <td>roster entry for this peer if in roster</td></tr>
        <tr><td><strong>type</strong><br>"desktop" | "cloud" | "laeproxy"</td>
            <td>type of Lantern peer<br><br>
            <strong><small>* cloud and laeproxy peers will have
            users associated with them via kaleidoscope</small>
            </strong></td></tr>
        <tr><td><strong>connected</strong><br><em>boolean</em></td>
            <td>whether user is currently connected to this peer</td></tr>
        <tr><td><strong>lastConnected</strong><br><em>date</em></td>
            <td>time the user last connected to this peer</td></tr>
        <tr><td><strong>version</strong><br><em>string</em></td>
            <td>(last known) version of client software the peer is running</td></tr>
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
        <tr><td><strong>bpsUpDn</strong><br><em>number</em></td>
            <td>instantaneous upload+download rate with this peer</td></tr>
        <tr><td><strong>bytesUp</strong><br><em>number</em></td>
            <td>lifetime bytes uploaded to this peer</td></tr>
        <tr><td><strong>bytesDn</strong><br><em>number</em></td>
            <td>lifetime bytes downloaded from this peer</td></tr>
        <tr><td><strong>bytesUpDn</strong><br><em>number</em></td>
            <td>lifetime bytes transferred with this peer</td></tr>
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
          <td><strong>bpsUpDn</strong><br><em>number</em></td>
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
          <td><strong>bytesUpDn</strong><br><em>number</em></td>
          <td>total number of bytes uploaded+downloaded since first signin</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>profile</strong> (<a href="https://developers.google.com/accounts/docs/OAuth2Login">OAuth2Login</a>)<br><em>object</em></td>
    <td>
      <table>
        <tr>
          <td><strong>email</strong><br><em>email</em></td>
          <td>The user's e-mail address.</td>
        </tr>
        </tr>
        <tr>
          <td><strong>name</strong><br><em>string</em></td>
          <td>The user's full name, if available.</td>
        </tr>
        <tr>
          <td><strong>link</strong><br><em>url</em></td>
          <td>A link to the user's Google Plus page, if available.
          </td>
        </tr>
        <tr>
          <td><strong>picture</strong><br><em>url</em></td>
          <td>Url of the user's picture, if available.
          </td>
        </tr>
        <tr>
          <td><strong>gender</strong><br><em>string</em></td>
          <td>The user's gender.</td>
        </tr>
        <tr>
          <td><strong>birthday</strong><br><em>string</em></td>
          <td>The user's birthday in the form YYYY-MM-DD, where YYYY may be
            "0000" if the contact does not display her birth year.</td>
        </tr>
        <tr>
          <td><strong>locale</strong><br><em>string</em></td>
          <td>The user's locale code, as in "en".</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>roster</strong><br><em>object[]</em></td>
    <td>List of contacts on the user's Google Talk roster <strong><em>with known
      email addresses</em></strong>. Used for auto-completing by name or email
      when the user is prompted to select friends to invite or request an
      invite from.<br>
      <table>
        <tr><td><strong>email</strong><br><em>email</em></td>
          <td>Contact's email address.</td></tr>
        <tr><td><strong>status</strong><br>"offline" | "available" |
          "idle" | "unavailable"</td>
          <td>Contact's online status.</td></tr>
        <tr><td><strong>statusMessage</strong><br><em>string</em></td>
          <td>Contact's status message.</td></tr>
        <tr><td><strong>name</strong><br><em>string</em></td>
          <td>Contact's full name, if available.</td></tr>
        <tr><td><strong>picture</strong><br><em>url</em></td>
          <td>Url of the contact's profile picture, if available.</td></tr>
      </table>
    </td></tr>
  </tr>
  <tr>
    <td><strong>friends</strong><br><em>object</em></td>
    <td>
      <table>
        <tr><td><strong>current</strong><br><em>object[]</em></td>
          <td>
            <table>
              <tr><td><strong>email</strong><br><em>email</em></td>
                <td>The friend's email address.</td>
              <tr><td><strong>name</strong><br><em>string</em></td>
                <td>The friend's full name, if available.</td>
              <tr><td><strong>picture</strong><br><em>url</em></td>
                <td>Url of the contact's profile picture, if available.</td></tr>
            </table>
          </td></tr>
        <tr><td><strong>pending</strong><br><em>object[]</em></td>
          <td><em>As in</em> <code>current</code>.</td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><strong>ninvites</strong><br><em>int</em></td>
    <td>The number of Lantern invites the user has remaining.</td>
  </tr>
  <tr>
    <td><strong>nproxiedSitesMax</strong><br><em>int</em></td>
    <td>The maximum number of configured proxied sites allowed.</td>
  </tr>
  <tr>
    <td><strong>settings</strong><br><em>object</em></td>
    <td>
      <table>
        </tr>
        <tr>
          <td><strong>lang</strong><br><em>string</em></td>
          <td>The user's language setting as a two-letter ISO 639-1 code.</td>
        </tr>
        <tr>
          <td><strong>runAtSystemStart</strong><br><em>boolean</em></td>
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
          <td><strong>proxyPort</strong><a href="#note-get-mode-only"><sup>1</sup></a><br><em>int</em></td>
          <td>The port the Lantern http proxy is running on.</td>
        </tr>
        <tr>
          <td><strong>pacUrl</strong><a href="#note-get-mode-only"><sup>1</sup></a><br><em>url</em></td>
          <td>The url of Lantern's pac file.</td>
        </tr>
        <tr>
          <td><strong>systemProxy</strong><a href="#note-get-mode-only"><sup>1</sup></a><br><em>boolean</em></td>
          <td>Whether to try to set Lantern as the system proxy.</td>
        </tr>
        <tr>
          <td><strong>proxyAllSites</strong><a href="#note-get-mode-only"><sup>1</sup></a><br><em>boolean</em></td>
          <td>Whether to proxy all sites or only those on
            <code>proxiedSites</code>.
          </td>
        </tr>
        <tr>
          <td><strong>proxiedSites</strong><a href="#note-get-mode-only"><sup>1</sup></a><br><em>string[]</em></td>
          <td>List of domains to proxy traffic to.</td>
        </tr>
      </table>
      <br><small><a name="note-get-mode-only">1</a> Only used when in "get" mode</small>
    </td>
  </tr>
</table>

<hr>


## HTTP API

All of the following endpoints should be accessed via POST request only.

<table>
  <tr><td><code>/interaction/<em>&lt;interactionid&gt;</em></code></td>
    <td>Notify the backend of the user interaction specified by
    <code>interactionid</code>, optionally passing associated data
    in a JSON-encoded request body, e.g. <code>POST /interaction/set</code>
    <br><br><code>{"path": "/settings/autoReport", "value": true}</code>
  <tr><td><code>/exception</code></td>
    <td>Notify the backend of the exception described by the JSON-encoded
    request body<br>
    <strong>XXX implement this</strong>
    </td></tr>
</table>

<hr>


## Reference implementations

lantern-ui's development server includes a mock backend to facilitate testing
and development (see [README.md](README.md)). The mock backend implementation,
found in the `/mock` directory, can serve as a reference implementation of
these specifications.

<hr>


## Notes

* Switches to Oauth rather than asking for users' Google passwords. Since we no
  longer store users' Google passwords, the data we do store is now much less
  sensitive. On Windows and OS X we continue to use the systems' keychain
  facilities for secure data storage. Pending [#357](https://github.com/getlantern/lantern/issues/357),
  on Ubuntu we ditch Lantern password-based settings unlock and just don't store
  anything sensitive like the Oauth token, instead just having the user complete
  a new Oauth workflow every time she restarts Lantern.

* Frontend does not maintain any state outside of the state document, e.g. no
  longer tries to keep track of which modal to display when, just does as it's
  told via the `modal` field.

* Frontend never modifies the state document; only notifies the backend of
  user interactions via the `interaction` api and the backend responds by
  updating the state document (and in some cases setting a non-200 response
  code)

<hr>


## Setup Sequence

* Welcome modal now prompts for give/get mode choice

    * Backend now checks country user is connecting from via geoip and only
      allows Give Mode if not in censoring country (Give Mode choice hidden)
    
    * If the country cannot be detected via geoip lookup (either because the
      user is offline or there is no match in the geoip database), the user
      should be allowed to choose either mode, but if a censoring country is
      detected in the future, the `giveModeForbidden` dialog should be displayed
      which forces a switch to Get Mode.

        * `connectivity.ip` and `location` should always be kept up-to-date
          as the user disconnects and reconnects from different places.

* Next is Oauth modal:

    * If Google cannot be reached, user is given option to proceed in
      demonstration mode and is told that Lantern will keep trying to connect
      in the background. Once backend is able to reach Google, it can set
      `modal` back to `authorize` to prompt user to try again.

    * If Google can be reached, Lantern should just prompt for Google Talk
      authorization until it has been granted.

    * Once we have an Oauth token, we know the user has successfully
      authenticated to Google.

    * Ideally, before we signed in to Google Talk, first we would check if the
      user has a Lantern invite, to save time waiting for the Google Talk sign
      in. The Lantern invite check is currently performed via XMPP message to
      lantern-controller, however, so we must sign in to Google Talk first.

    * After signing in to Google Talk, we compare the user's roster to the set
      of invited Lantern users to determine which of her contacts are Lantern
      users. This is needed by the `lanternFriends` modal and the
      `requestInvite` modal.

    * Next we check if the user has Lantern access (i.e. has an invite).

    * If no invite, present the `notInvited` modal, which allows user to try
      using a different account (i.e. goes back to `authorize` modal), or
      request an invite via the `requestInvite` modal, and then proceed in
      demonstration mode. When the user gets an invite, backend should
      discover this and set modal to `firstInviteReceived`, and then take
      user back to the remaining setup modals. In demonstration mode,
      Lantern will keep the user signed in to Google Talk, but will not
      allow participation with Lantern peers.

    * If the user has an invite, we proceed to `lanternFriends` modal.

    * Note: We no longer allow switching Google accounts once we've
      successfully signed in as a user with Lantern access. Switching accounts
      should require a full reset.

* Next is `lanternFriends` modal:

    * `lanternFriends` is now a setup modal, to introduce the important concept
      of the trust network at the outset. User may not have any invites to give
      out yet, but will be told to expect to receive more as she continues to
      run Lantern. This modal also allows the user to see which of her contacts
      are already Lantern users and therefore already Lantern friends, as well
      as manage any pending Lantern friend requests from users not on her
      roster.

* Next, Get Mode users are presented with the `proxiedSites` modal, introducing
  the important concept that Lantern only proxies traffic to certain sites, and
  then the `systemProxy` modal, before reaching the `finished` modal.

* Give Mode users are taken directly from `lanternFriends` to `finished`.
  Backend should remember that the `proxiedSites` and `systemProxy` modals
  have never been completed, so that if the Give Mode user ever switches to
  Get Mode, the backend can immediately take her back there.
