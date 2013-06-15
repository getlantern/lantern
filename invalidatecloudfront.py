#!/usr/bin/env python

import sys
import boto

c = boto.connect_cloudfront()
rs = c.get_all_distributions()
ds = rs[1]
distro = ds.get_distribution()
#print distro.domain_name
#print distro.id
paths = ['/latest.exe', '/latest.dmg', '/latest-64.deb', '/latest-32.deb']

print "Invalidating all latest installers on CloudFront..."
inval_req = c.create_invalidation_request(u'E1D7VOTZEUYRZT', paths)
status = c.invalidation_request_status(u'E1D7VOTZEUYRZT', inval_req.id)
#print status.paths
#print status.paths[0]
