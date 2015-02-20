#!/bin/sh

CONFIGDIR=`dirname $0`/../config
CONFIGFILE=$CONFIGDIR/compass.rb

compass watch -c $CONFIGFILE
