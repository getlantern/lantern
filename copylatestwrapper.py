#!/usr/bin/env python

import sys
import boto
from boto.s3.key import Key

if len(sys.argv) != 2:
  sys.exit("Usage: origin net-installer prefix expected, as in 'zodsmxt3'")

newestprefix = str(sys.argv[1])


conn = boto.connect_s3()
b = conn.get_bucket('lantern-installers')

keys = b.list()

osx = newestprefix + '/lantern-net-installer_macos_0_0_1.dmg'
linux = newestprefix + '/lantern-net-installer_unix_0_0_1.sh'
win = newestprefix + '/lantern-net-installer_windows_0_0_1.exe'

print win

newestosx = Key(b)
newestosx.key = osx
newestwin = Key(b)
newestwin.key = win
newestlinux = Key(b)
newestlinux.key = linux
for key in keys:
  #print key.name
  if key.name.startswith(newestprefix):
    print 'not copying from origin bucket ' + key.name
  else:
    print 'attempting to copy from '+osx+' to '+key.name
    if key.name.endswith('dmg'):
      src = newestosx
    elif key.name.endswith('exe'):
      src = newestwin
    elif key.name.endswith('sh'):
      src = newestlinux
    else:
      print 'bad name: '+key.name
      continue
    print 'Copying from '+src.key+' to '+key.name
    src.copy('lantern-installers', key.name, preserve_acl=True)
