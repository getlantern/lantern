Quick and dirty Flashlight notes.

Long term would be great to allow fallbacks to register themselves with peerdnsreg. That way we just spool them up, and they auto-register.

We could also look at a subdomain addressing scheme based on geography.

Create droplet
Add flashlight user
Copy root .ssh/authorized_keys to flashlight/.ssh/authorized_keys

set up IP tables — iptables.rules in flashlight home directory — look for port 62443

download and install Go Linux 64 bit.
Add Go to PATH
Setup GOPATH in .profile or wherever

Install git
Install mercurial
go get flashlight

copy /etc/init/flashlight.conf (from an existing server) to make it run on startup — CHANGE THE SERVER IN flashlight.conf

Change the ulimit — /etc/security/limits.conf (restart?)


Make /home/flashlight/flashlight-working-dir
All logging goes to syslog


export GOPATH=~/gopath
export PATH="$GOPATH/bin:$PATH"
* hard nofile 1024768
* soft nofile 1024768
root hard nofile 1024768
root soft nofile 1024768

In peerdnsreg update_load_balancer Ox’s deletes Singapore and then recreates. Added update_fallback_proxy in lib.py

heroku logs -t will tail the logs
To deploy you just commit your change 

git push heroku master — Heroku automatically picks up the change

flushed will flush the redis db, forcing an update

cleared the state

Need to make iptables rules sticky across restarts

apt-get install ip-tables-persistent





