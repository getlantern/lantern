# This script prepares the .lantern folder for running the unit tests. It
# copies the file test.properties into the ~/.lantern folder.
#
# WARNING - never commit the unencrypted contents of test.properties to the
# lantern repo, as it contains secret information.  The file is versioned in
# too-many-secrets.
#
# For use by Travis, test.properties is encrypted into test.properties.enc. See
# http://docs.travis-ci.com/user/encrypting-files/ for more information.

function die() {
  echo $*
  exit 1
}

rm -Rf ~/.lantern || die "Unable to clear .lantern folder"
mkdir -p ~/.lantern || die "Unable to create .lantern folder"
echo "Copying test.properties to ~/.lantern"
cp test.properties ~/.lantern || die "Unable to copy test.properties to ~/.lantern"

./copypt.bash || die "Unable to copy pluggable transports"