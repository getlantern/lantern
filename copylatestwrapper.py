#!/usr/bin/env python

import sys
import boto
from boto.s3.key import Key

if len(sys.argv) != 2:
  sys.exit("Usage: origin net-installer prefix expected, as in 'zodsmxt3'")

latestprefix = str(sys.argv[1])


conn = boto.connect_s3()
b = conn.get_bucket('lantern-installers')

keys = b.list()

osx = latestprefix + '/lantern-net-installer_macos_0_0_1.dmg'
linux = latestprefix + '/lantern-net-installer_unix_0_0_1.sh'
win = latestprefix + '/lantern-net-installer_windows_0_0_1.exe'

print win

latestosx = Key(b)
latestosx.key = osx
latestwin = Key(b)
latestwin.key = win
latestlinux = Key(b)
latestlinux.key = linux
for key in keys:
  #print key.name
  if key.name.startswith(latestprefix):
    print 'not copying from origin bucket ' + key.name
  else:
    print 'attempting to copy from '+osx+' to '+key.name
    if key.name.endswith('dmg'):
      src = latestosx
    elif key.name.endswith('exe'):
      src = latestwin
    elif key.name.endswith('sh'):
      src = latestlinux
    else:
      print 'bad name: '+key.name
      continue
    print 'Copying from '+src.key+' to '+key.name
    src.copy('lantern-installers', key.name, preserve_acl=True)
