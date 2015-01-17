# peerdnsreg - register flashlight peer and fallback servers

peerdnsreg is a HTTP-based service for registering and unregistering flashlight servers so they can be used by the flashlight clients that run in Lantern installations when in get mode.

Pedantic note for the fastidious: for agility of exposition we say "flashlight server" to refer loosely to the machine where the flashlight server is running.  Currently, the calls described below are made not by the flashlight program itself but by the Lantern client that is controlling it.

## Operation

flashlight servers call a peerdnsreg endpoint periodically to advertise their availability and up-to-date contact details.  If they have a chance, they also inform peerdnsreg when they become unavailable.  Otherwise, peerdnsreg will automatically unregister a server from which it hasn't received updates for too long.

### Registering

A flashlight server registers itself by making a POST request with the `/register` path.  The request parameters for this call are:

- `name`: a string identifier that is not equal to that of any other machine registering in peerdnsreg. It must be a valid subdomain name, *and* a valid [VCL](https://www.varnish-cache.org/docs/3.0/reference/vcl.html) identifier when prepended `f_`.  To be on the safe side, use only ASCII digits and lowercase letters.  Lantern peer clients use their `instanceId`, which meets these conditions.

- `ip`: the public IP of the flashlight server (e.g. `54.230.90.149`.)

- `port`: the port where this flashlight server can be reached from external clients (so, if the server is port mapped in a NAT, this would be the external port).

### Heartbeat

peerdnsreg will unregister any servers from which it hasn't received a `/register` request in [five minutes](https://github.com/getlantern/peerdnsreg/blob/cd389870fea40eeee55ea00369b342c6bcd2521e/lib.py#L25).  To prevent this automatic unregistration, flashlight servers need to send periodical registration requests, with the same parameters as indicated above, more often than that.

### Unregistration

If it has a chance, a flashlight server will announce that it is becoming unavailable by making a POST request with path `/unregister`.  The only parameter is the `name` it provided back when it registered.

## Deploying

At the moment peerdnsreg is a Heroku app.  For the basics of operating with Flask/Python on Heroku see:

https://devcenter.heroku.com/articles/getting-started-with-python

The credentials required to deploy new versions to the production account are in `too-many-secrets/peerdnsreg.txt`.

## Installing for local testing

The particular requirements of this app are contained in a `requirements.txt` file.  You only need these if you want to test your changes locally with `foreman start` (recommended.)  Once you have pip and a virtualenv set up as indicated in the tutorial referred to in the **Deploying** section, you should be able to install all the requirements by running `pip install -r requirements.txt`.

In addition, you need to set some environment variables.  See how to do that in the comment at the beginning of [set_config.py](https://github.com/getlantern/peerdnsreg/blob/master/set_config.py).

## How it works

### Processes

Actual work is defined in [lib.py](https://github.com/getlantern/peerdnsreg/blob/master/lib.py), and is performed by a [worker process](https://github.com/getlantern/peerdnsreg/blob/master/rq_worker.py) that pulls tasks off a [RQ](http://python-rq.org/) queue.  Tasks are fed to that queue from two sources:

- [app.py](https://github.com/getlantern/peerdnsreg/blob/master/app.py) is a minimal [Flask](http://flask.pocoo.org/) app defining the public HTTP API.

- [stale_checker.py](https://github.com/getlantern/peerdnsreg/blob/master/stale_checker.py) periodically removes timed out registrations.

These processes are started in [start-web.bash](https://github.com/getlantern/peerdnsreg/blob/master/start-web.bash) so they'll run in a single dyno.  This was done to stay on the free Heroku plan.  Since this was initially targeting Cloudflare, I believed that we would hit their rate limit before we needed to scale up our heroku deployment.  I don't know what frequency of updates we can have in Fastly, but it's trivial to scale up by launching the different processes directly in the [Procfile](https://github.com/getlantern/peerdnsreg/blob/master/Procfile) instead.

### Registrations

flashlight servers are currently registered in [Fastly](http://www.fastly.com).  Support for [Cloudflare](https://www.cloudflare.com) is planned in the short term, and other CDNs that support [host spoofing](https://getlantern.org/blog/lantern-1-3-1/index.html) may be implemented after that.

We create a Fastly (that is, [Varnish](https://www.varnish-cache.org/)) [backend](http://docs.fastly.com/api/config#backend) for each flashlight server.  In addition, we create a [condition](http://docs.fastly.com/guides/article/23472072-Conditions-Tutorial) to allow that server to be reached by subdomain name, and we [add](http://docs.fastly.com/api/config#director_backend) the backend to a [director](http://docs.fastly.com/api/config#director) for load balancing.

Details on registration are stored in a [Redis](http://redis.io) instance so we don't hit Fastly more than necessary.  (When we used Cloudflare we also kept here an ID for undoing the registration.)
