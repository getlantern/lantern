#!/usr/bin/env python

import sys
import boto
from boto.s3.key import Key

key = str(sys.argv[1])

if key.endswith('dmg'):
    latest = 'latest.dmg'
elif key.endswith('exe'):
    latest = 'latest.exe'
elif key.endswith('32.deb'):
    latest = 'latest-32.deb'
elif key.endswith('64.deb'):
    latest = 'latest-64.deb'
else:
    print 'File name with full version required. .deb files should end in 32.deb or 64.deb'
    sys.exit()   

conn = boto.connect_s3()
b = conn.get_bucket('lantern')

k = Key(b)
k.key = key
k.copy('lantern', latest, preserve_acl=True)
