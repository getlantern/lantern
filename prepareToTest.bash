# This script prepares the .lantern folder for running the unit tests.
# It depends on some environment variables:
#
#   REFRESH_TOKEN - The Google OAuth refresh token for the account with which
#                   we're testing
#   ACCESS_TOKEN  - The Google OAuth access token for the account with which
#                   we're testing
#
# Note - we specify these as environment variables to take advantage of Travis
# CI's encryption mechanism.
# See http://docs.travis-ci.com/user/encryption-keys/.

function die() {
  echo $*
  exit 1
}

rm -Rf ~/.lantern || die "Unable to clear .lantern folder"
mkdir -p ~/.lantern || die "Unable to create .lantern folder"
echo "refresh_token=${REFRESH_TOKEN}" > ~/.lantern/test.properties || die "Unable to set refresh token"
echo "access_token=${ACCESS_TOKEN}" >> ~/.lantern/test.properties || die "Unable to set access token"

./copypt.bash || die "Unable to copy pluggable transports"