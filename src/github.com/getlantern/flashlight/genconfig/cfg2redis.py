#!/usr/bin/env python

import hashlib
import os
import sys

try:
    import redis
except ImportError:
    print "This requires redis-py.  Try something like"
    print "    pip install hiredis ; pip install redis"
    sys.exit(1)
try:
    import yaml
except ImportError:
    print "This requires PyYaml.  Try something like"
    print "    pip install pyyaml"
    sys.exit(1)

def r():
    if not hasattr(r, 'r'):
        url = os.getenv("REDISCLOUD_PRODUCTION_URL")
        if url is None:
            print "A REDISCLOUD_PRODUCTION_URL environment variable is required."
            print
            print "Try `heroku config` in the root of the getlantern/config-server"
            print "project to get the production one, or use 127.0.0.1:6379 for"
            print "local testing (requires a running redis service)."
            sys.exit(1)
        r.r = redis.from_url(url)
    return r.r

def reset():
    print
    print "*** WARNING ***"
    print
    print "THIS WILL WIPE OUT THE DATABASE!!!"
    print
    if raw_input("Are you sure? (y/N): ").strip().lower() not in ["y", "yes"]:
        sys.exit(0)
    r().flushall()

def feed(src, dc, globalcfg=False, dccfg=False, setdefaultdc=False, srv=False):
    p = r().pipeline(transaction=True)
    cfg = yaml.load(file(src))
    servers = cfg['client']['chainedservers']
    if dccfg:
        dccfg = "\n    " + yaml.dump(cfg['client']['frontedservers'])
        p.hset("cfgbydc", dc, dccfg)
        if not r().exists(dc + ':slices'):
            p.zadd(dc + ':slices', '<empty>', 1 << 32)
    if setdefaultdc:
        p.set("defaultdc", dc)
    if globalcfg:
        cfg['client']['frontedservers'] = "<DC CONFIG HERE>"
        cfg['client']['chainedservers'] = "<SERVER CONFIG HERE>"
        globalcfg = yaml.dump(cfg)
        p.set("globalcfg", globalcfg)
        p.set("globalcfgsha", hashlib.sha1(globalcfg).hexdigest())
    if srv:
        p.rpush(dc + ":srvq",
                *("%s|\n    %s" % (v['addr'].split(':')[0], yaml.dump({k: v}))
                  for k,v in servers.iteritems()))
    p.execute()

def usage():
    print "%s [<opts>] src dc" % sys.argv[0]
    print "Options:"
    print "    --global : Upload global config."
    print "    --dc : Upload dc config."
    print "    --defaultdc : Set dc as default."
    print "    --srv : Upload chained server config."
    sys.exit(1)

if __name__ == '__main__':
    opts = sys.argv[1:]
    glb = dc = defaultdc = srv = False
    try:
        opts.remove("--global")
        glb = True
    except ValueError:
        pass
    try:
        opts.remove("--dc")
        dc = True
    except ValueError:
        pass
    try:
        opts.remove("--defaultdc")
        defaultdc = True
    except ValueError:
        pass
    try:
        opts.remove("--srv")
        srv = True
    except ValueError:
        pass
    try:
        src, dc = opts
    except ValueError:
        usage()
    if not (glb or dc or defaultdc or srv):
        print "You must set one of the flags!"
        usage()
    feed(src, dc, glb, dc, defaultdc, srv)
