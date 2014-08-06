#!/usr/bin/env python

import sys
import boto
from boto.s3.key import Key

if len(sys.argv) < 2:
    print "Need file name and base name of generic latest installer, as in 'copys3file.py lantern-1.4.4-6dfa980.dmg lantern-installer'"
    sys.exit(1)
 
# DRY: deployBinaries.bash
BUCKET = 'lantern'

key = str(sys.argv[1])
newestname = str(sys.argv[2])

if key.endswith('dmg'):
    ext = '.dmg'
elif key.endswith('exe'):
    ext = '.exe'
elif key.endswith('32-bit.deb'):
    ext = '-32.deb'
elif key.endswith('64-bit.deb'):
    ext = '-64.deb'
else:
    print 'File name with full version required. .deb files should end in 32-bit.deb or 64-bit.deb'
    sys.exit(1)

#newest = newestname + ext

# This is all actually handled externally. TODO -- do it all here! Fix deployBinaries and releaseExisting and do everything through boto/python
newest = newestname
print 'Newest name %s' % newest

conn = boto.connect_s3()

b = conn.get_bucket(BUCKET)

k = Key(b)
k.key = key
k.copy(BUCKET, newest, preserve_acl=True)

# Since we've just updated the fixed name 'lantest.x' file in our bucket,
# we need to make sure to invalidate it on cloudfront in case anyone's
# using it.
#print 'Invalidating newest installers on CloudFront...'
#c = boto.connect_cloudfront()
#paths = [newest]
#inval_req = c.create_invalidation_request(u'E1D7VOTZEUYRZT', paths)
#status = c.invalidation_request_status(u'E1D7VOTZEUYRZT', inval_req.id)
