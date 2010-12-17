#/usr/bin/env bash

# This can be useful for testing of making sure the proxy is returning the same files as 
# direct connections.

function die() {
  echo $*
  exit 1
}


sites="cloudfront.littleshoot.org/littleshoot-desktop.m4v www.news.com www.littleshoot.org www.download.com"

COUNTER=0
for site in $sites
do
    curl -H 'Accept-Encoding: gzip,deflate' -x 127.0.0.1:8787 "http://$site" > lantern_$COUNTER.out
    curl -H 'Accept-Encoding: gzip,deflate' "http://$site" > $COUNTER.out
    diff lantern_$COUNTER.out $COUNTER.out || die "Files differ: lantern_$COUNTER.out and $COUNTER.out for site $site"
    let COUNTER=COUNTER+1
done

