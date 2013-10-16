Lantern: Security considerations
================

Overview
----------

Lantern is a censorship circumvention tool focused on efficiency,
convenience, and availability.  Anonymity is explicitly not a goal.
To the extent possible, Lantern attempts to avoid being detectable by
censoring regimes.  However, with present technology, this is not 
reliably possible.  So, Lantern should not be used where censorship
circumvention is punished.

Lantern consists of:

- The lantern client (Java, desktop, cross-platform)
- The lantern client installer downloader (Java, desktop, cross-platform)
- lantern-controller (Java, Google App Engine)
- laeproxy (Java, Google App Engine)
- AWS "Invited Servers" (instances of the lantern client on AWS)
- AWS "Invited Server Launcher" (Python, AWS)

The lantern client has two modes of operation: give and get.  

Give mode is intended for users in uncensored counries.  It is
disabled when Lantern detects (from the GeoLiteCity ip address
database) that it is in a censored country.  In Give mode, Lantern
acts as a HTTP proxy for Get mode clients.

Get mode is intended for users in censored countries (but anyone can
use it).  In Get mode, Lantern acts as a local HTTP proxy, forwarding
HTTP requests over SSL to give mode peers and various fallback
proxies.  Peers are discovered via the Kaleidoscope protocol over
XMPP (over SSL).

Social network
--------------

Lantern's social network is an overlay on Google Talk.  All peers use
OAuth 2.0 to authenticate to Google Talk.  Give mode peers connect
directly to Google's oauth servers over HTTPS.  Get mode peers connect 
to Google OAuth via fallback proxies.  Then they connect directly to
Google Talk, which is assumed to be not blocked.

Lantern users log in with an XMPP resource containing the substring
-lan-, which Lantern uses to decide which XMPP peers should get
Kaleidoscope messages (Roster.java#131).

Lantern automatically adds the Lantern Controller XMPP user to their
XMPP roster.

Lantern users can choose whom they trust.  At installation time,
Lantern allows users to choose "friends" among their XMPP roster or by
entering email addresses directly.  The friend relationship is
one-way: if A has B listed as a friend, this means that A trusts B and
will send Kaleidoscope messages to B and accept them from B.  If a
user friends another user who is not on their XMPP roster, they will
attempt to XMPP subscribe to that XMPP user (and accept that XMPP
user's subscription request, if and when one is sent).  This
subscription is necessary to know when the user is online (and thus
can receive Kaleidoscope notifications).

Lantern friends are synchronized to the controller, so that if a user
is running multiple clients (or loses their local data), their network
is preserved

### Known issues ###

If Google stops maintaining XMPP servers (for instance, due to their
deprecation of Talk in favor of Hangouts), then Lantern would no longer
operate anywhere.

Anyone who is subscribed to a user over XMPP can tell that they are
Lantern users by the -lan- substring in their XMPP resource.  Lantern
depends on this to recommend new friends.

Invitations
-----------

At present, in order to use Lantern in either give mode or get mode, a
user must be invited to join the network by an existing user.

When a user friends another user whom they do not know to be already a
Lantern user:

* The inviter's **Lantern client** sends an XMPP message to the
  **Lantern controller**, notifying it that `inviter@gmail.com` wants
  to invite `buddy@gmail.com`.  This request also includes some
  credentials (i.e. a *refresh token*) that allows the bearer to login
  to Google Talk as `inviter@gmail.com`.

* The controller queues this invitation, allowing BNS to pick and
  choose which friendings become real invitations.  (The client also
  queues the invitation until the server acknowledges it, so that
  invitaitons aren't lost).  Invites from admin users (BNS staff) are
  dequeued automatically.

* When an invitation is dequeued, **Lantern controller** sends an XMPP
  (XXX SQS?) message to the **invited server launcher**, asking it to
  create a new **Invited Server** that will run as the inviter.  To
  this end, it sends the refresh token it was passed from the Lantern
  client, and the name of the S3 bucket where the installers created
  by this server should be stored.

* The **invited server launcher** spawns and configures a new
    **Invited Server** with the given refresh token and bucket name.

* The **Invited Server** configures a Lantern installer downloader and
  uploads it to a 'folder' with a randomly generated name (XXX) in the
  given bucket, builds Lantern itself and runs it as a service, then
  notifies **Lantern controller** that it's done starting up, passing
  it the location where the installer downloader has been uploaded.
    
  The newly built installer downloader includes the address of the
  Invited Server as a fallback proxy.

* The **Lantern controller** stores the installer downloader location
  for `inviter@gmail.com` and sends an e-mail to `buddy@gmail.com`
  (and to whomever else may have been invited by `inviter@gmail.com`
  while the previous steps were taking place), telling them that they
  were invited, and where they can download a Lantern installer for
  their platform.

* From here on, whenever `inviter@gmail.com` invites a new buddy, the
  invite e-mail will be sent immediately to them (upon dequeue), using
  the install location stored for the inviter.

### Known issues ###

If lantern-controller, the invited server launcher, or an invited
server is compromised, an adversary could impersonate the user on
Google Talk, exposing them and their contacts to risks.

See also the [EC2](#EC2) section


Lantern Controller
------------------------
Lantern Controller has an admin interface.  Access is controlled via OAuth.  BNS staff have access.  The admin interface can turn on/off invitation queueing (allowing all invitations to go through), and dequeue particular invitations.  

AppEngine’s admin interface allows BNS staff to view and edit all controller data.  Access is controlled via Google login.

LAEProxy
--------

LAEProxy is a proxy that runs on Google App Engine.  App Engine does
not support HTTP CONNECT, so proxying happens over HTTP GET/POST.
This causes problems on https sites, because the client's browser
cannot authenticate the proxied site.  We could use MITMProxy-like
techniques to solve this, but that would expose the user's HTTP
traffic to Google App Engine.

LAEProxy is not actually used right now.

Centralized fallback proxy
--------------------------

BNS also maintains a fallback proxy for development purposes.  This 
is not used for ordinary Lantern clients.

Invited servers
---------------

Invited servers run the same software as Lantern's desktop client.  They
run on Amazon EC2 micro instances.

Invited servers act as fallback proxies, so that users can connect to
Google Talk (if it is blocked) and kick off the rest of the proxy
discovery process.

Users authenticate the invited servers using a SSL certificate that is
distributed with the installer.

The invited servers also need to authenticate users (#798), so that
censoring regimes can't detect that it is a proxy.  And we need to
switch to a dynamically generated SSL cert for the server, so that
connections which use that SSL cert can't be blocked (#799).

### Known issues ###

BNS can only afford a small number of these servers (relative to the
number of prospective Lantern users).  So, we'll have to start sharing
them, or finding new funding sources.

### <a name="EC2"> ###
IF EC2 were blocked in some country, the entire lantern distribution
and fallback proxy scheme would fall apart in that country.
Diversifying cloud hosting providers could help with this.


Statistics
----------

Lantern stores anonymous usage statistics: numbers of users, peers,
and bytes transfered by country.  These statistics are maintained
by lantern-controller.  

STUN
----

The Lantern client uses STUN to determine its public IP address.  The
public IP address is used to determined the country in order to
prevent give mode in censored contries.  

### Known issues ###

STUN servers are always accessed in the same order, which might allow
Lantern to be detected.

UDT
---

Lantern uses the Barchart-UDT library to provide connectivity over UDP
when TCP connections cannot be established (for instance due to
firewalls).

### Known issues ###

UDT is rare and could allow Lantern to be fingerprinted.


Proxy discovery
------------

Lantern achieves its censorship resistance by only telling each get
mode peer about a limited subset of proxies.  The subset is based on
the user's XMPP social network.  The Kaleidoscope protocol is designed
to do this in a secure manner.  Lantern implements only the "Limited
relay advertisement" portion of Kaleidoscope; the "Traffic forwarding"
>portion is not implemented.  According to the Kaleidoscope paper, this
will not allow all get-mode users to reach a proxy.  The percent who
can reach a proxy depends on the level of infiltration of the network
and the ratio of give-mode users to get-mode users.  With 10%
give-mode users, and levels of infiltration under 2%, well over 99% of
get-mode users should be able to reach some proxy.

Details of the Kaleidoscope protocol itself are outside the scope of
this document.  For more information about, see:

Unblocking the Internet: Social networks foil censors Yair Sovran,
Jinyang Li, Lakshminarayanan Submaranian NYU Computer Science
Technical Report TR2008-918, Sep 2009
http://kscope.news.cs.nyu.edu/pub/TR-2008-918.pdf

Lantern's implementation of Kaleidoscope's limited relay advertisement
can be found at: https://github.com/getlantern/kaleidoscope

In addition to proxies discovered through Kaleidoscope, Lantern uses
fallback proxies, which are operated by Brave New Software on EC2 on
behalf of its users.  We have not analyzed how this will affect
availability.

In particular, a Lantern proxy advertises itself as follows:

  1. Tell all its immediate Lantern friends about it (these are people whom the
     Give mode user explicitly added as a friend).  In particular, it's telling
     them:
     * The exact JID of the Lantern instance (assigned by Google Talk on startup
       of Lantern)
     * The ip address of the instance, both on its own LAN and as seen on the
       internet
     * If it was able to map a port using UPnP or NAT-PMP, the mapped port
  2. Each of these friends forwards this advertisement to a subset of their
     Lantern friends     
  3. Step 2 is repeated out to 4 levels (this depth could change, but it's a
     globally applied setting)

Cryptography
------------

Lantern uses SSL for all connections that it initiates (except STUN,
which does not support SSL).  The SSL certificate for Google
Talk is pinned.  

The Bouncy Castle SSL provider is used.

Lantern uses TLS\_ECDHE\_RSA\_WITH\_AES\_256\_CBC\_SHA when it can.  It falls
back to TLS\_ECDHE\_RSA\_WITH\_AES\_128\_CBC\_SHA.  

Certificate Exchange
--------------------

Lantern proxies and clients mutually authenticate using
[public key certificates](http://en.wikipedia.org/wiki/Public_key_certificate).
These certificates are exchanged via XMPP messages between the client and the
proxy sent through Google Talk.  The exchange happens as a result of the client
becoming aware of the server through the Kaleidoscope advertising process
(see above).

Once the client becomes aware of a proxy, the client sends that proxy its own
certificate via a direct XMPP message to the JID in the Kaleidoscope
advertisement.  Note - we do not relay this message through the chain of friends
that advertised the proxy because that would require all of them to be online
at the time that the client wants to access the internet, which would severely
restrict availability.

When the proxy receives the client's certificate, it implicitly trusts it.
This works because the only way that Google Talk's XMPP server will deliver the
message is if either:
  
  1. The peer sent the message to the exact JID for the running Lantern instance
     (e.g. email@company.com/23432adf), which is only made available through the
     Kaleidoscope discovery process.
  2. The users are on already each other's rosters, meaning that the proxy's
     user at some point explicitly authorized the client to chat with him/her on
     Google Talk.

In addition to trusting the client's certificate, the proxy immediately sends
its certificate to the client via XMPP.  The client implicitly trusts the
proxy's certificate for the same reasons that the proxy trusted the client's.

On both ends, if the user explicitly rejected the other user as a Lantern
friend, the certificate received via XMPP will not be trusted.


### Open questions ###

- What revisions did Lantern make to the Kaleidoscope algorithm?  How does
that affect its security and performance?

- How does Kaleidoscope work when not all peers are online?

- How does Kaleidoscope (or Lantern's implementation thereof) handle
  multiple peers representing the same user?

### Future plans ###

We would like to allow any user to sponsor a cloud proxy; that proxy would
be treated as that user for the purposes of Kaleidoscope routing.

It would also be nice to support obfsproxy.

