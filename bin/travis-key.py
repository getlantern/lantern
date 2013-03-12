#!/usr/bin/env python

if __name__ == "__main__":
    
    import urllib2
    import json

    resp = urllib2.urlopen("https://api.travis-ci.org/repos/getlantern/lantern/key")

    dat = json.loads(resp.read())
    rsakey = dat.get("key", False)

    print rsakey.strip()
