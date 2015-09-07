# Lantern Documentation for Developers

This is the main README for Lantern internal documentation, which outlines the different parts and links to the READMEs providing in-depth explanations of each particular sub-project.


## Overview

Let's start by describing what happens when the user decides to download Lantern and use it:

1. First, recall that the user is probably not living in a country with free internet, and has to use an alternate method of grabbing a copy of the Lantern installer.  At this point, we've already touched two crucial processes of Lantern: installer generation and installer distribution. Installer generation is currently a manual process handled by Lantern [Makefile](https://github.com/getlantern/lantern/blob/valencia/Makefile) (see _package-*_ tasks).  Installer distribution is in flux, as better ways are proposed and implemented. But mainly, it is done via direct download from CDNs or Github, and in case these are blocked, the mail autoresponder (see [Lantern Cloud](#lantern cloud)).

1. Once the user grabs a copy for any of the supported OSs (Linux, OS X, Windows, or mobile), it will be installed accordingly.  The packages are prepared for making this as easy as possible (see [installer resources](https://github.com/getlantern/lantern/tree/valencia/installer-resources)).

1. The first time the user runs Lantern, it will work with its embedded configuration.  This implies that the bootstrapping configuration is widely distributed, and can be used by censors to easily automate blocking as this information is openly provided to all users that download Lantern without distinction. The part that handles the generation of this embedded configuration is [genconfig](https://github.com/getlantern/lantern/tree/valencia/src/github.com/getlantern/flashlight/genconfig), which relies also upon some parts of Lantern Cloud, mainly for obtaining the updated list of servers that Lantern has deployed.

1. Lantern relies critically on the previous step. If it succeeds, that means it can use the embedded configuration to gain access to the free internet, via one of the different kinds of servers that Lantern has deployed.  But using this method as the only path to the free Internet from then on is problematic: if the censors have this information, it can be used easily block all Lantern users' access.  Thus, at this point, the Lantern client is ready to attempt to obtain a config that will make the whole Lantern network more resilient, without the limitations of the distribution channel used for the generic installer.  For this purpose, the Lantern client will try periodically to contact the [config-server](https://github.com/getlantern/config-server), whose responsibility is generating the configuration and maintaining the logic behind server assignations.

1. Once a more resilient and unique configuration is received (which will periodically be polled for updates), Lantern can use any of the types servers in the Lantern cloud (either LCS or LFS -- aka fallbacks or chained servers and flashlight or fronted server).  There are few techniques used by Lantern for proxying.  In a nutshell, Lantern will act as an HTTP/HTTPS proxy that will listen in a local port for requests.  These requests will be redirected in different ways to a server that will reach the open internet.  These servers can be peers (to be done!), as well as the 2 kinds of Lantern-hosted servers mentioned before.  This is described more in more detail in the [Lantern Core section](#lantern-core).


Concurrently to normal Lantern client working:

* Autoupdates


What happens in the cloud

* Maintenance tasks: peerscanner, checkfallbacks, sonar



## Lantern Cloud

**This concerns the following projects:**

* **[lantern_aws](https://github.com/getlantern/lantern_aws)**
* **[lantern-controller](https://github.com/getlantern/lantern-controller)**
* **[config-server](https://github.com/getlantern/config-server)**
* **[autoupdate-server](https://github.com/getlantern/autoupdate-server)**
* **[sonar](https://github.com/getlantern/sonar)**
* **[mail-autoresponder](https://github.com/getlantern/mail-responder)**

Other parts of the cloud infrastructure are hosted within the main Lantern repository, such as:

* **[peerscanner](https://github.com/getlantern/lantern/tree/valencia/src/github.com/getlantern/peerscanner)**
* **[autoupdate-server](https://github.com/getlantern/lantern/tree/valencia/src/github.com/getlantern/autoupdate-server)**
* **[checkfallbacks](https://github.com/getlantern/lantern/tree/valencia/src/github.com/getlantern/checkfallbacks)**
* **[flashlight (in server mode)](https://github.com/getlantern/lantern/tree/valencia/src/github.com/getlantern/flashlight)**

### Lantern AWS

This is the central repository of DevOps operations in Lantern. It uses SaltStack for cloud orchestration and automation.


***** DESCRIBE HERE OTHER PROCESSES IN THE CLOUD *****


## Lantern Core

**This concerns the project in this repository: [lantern](https://github.com/getlantern/lantern).**

This is the repository of the Lantern desktop application, but it also hosts some utilities and Go packages used elsewhere (see [Lantern Cloud](#lantern-cloud)).

** Describe most important packages and parts **


## Lantern Mobile

**This concerns the project in this repository: [lantern-mobile](https://github.com/getlantern/lantern-mobile).**

Although it is hosted as part of [lantern](https://github.com/getlantern/lantern), it can be considered a separate project within Lantern due to its importance.
