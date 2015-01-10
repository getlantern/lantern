#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

if [ $# -ne "2" ]
then
  die "$0: Received $# args, expected base names of stable and beta, as in
  './releaseBeta.bash lantern-1.5.15-83ff811 lantern-1.5.16-c28367e'"
fi

STABLE_VERSION=$1
BETA_VERSION=$1
./releaseExisting.bash $STABLE_VERSION lantern-installer || die "Could not
release stable"
./releaseExisting.bash $BETA_VERSION lantern-installer-beta || die "Could not
release beta"

STABLE=`echo $STABLE_VERSION | cut -d "-" -f 2`
BETA=`echo $BETA_VERSION | cut -d "-" -f 2`
./uploadversion.bash $STABLE $BETA || die "Could not upload
version!"
