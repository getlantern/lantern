#!/bin/bash

# Lantern wrapper.
# Copyright (c) 2015. Lantern Team <team@getlantern.org>.

# Lantern could probably use this LANTERN_WRAPPER env var in the future.
export LANTERN_WRAPPER=$(readlink -f "$0")

echo "Running installation script..."
LANTERN_WRAPPER_DIR=$(dirname "$LANTERN_WRAPPER")

# This is the original Lantern binary that came with the installer, it's
# probably out of date.
LANTERN_SOURCE_BINARY=$LANTERN_WRAPPER_DIR/lantern-binary

# This is a packaged yaml config file allowing us to include configuration
# in the package outside of the binary itself to enable configuration
# that is still compatible with auto-updates.
LANTERN_SOURCE_YAML=$LANTERN_WRAPPER_DIR/.packaged-lantern.yaml

# This is the file containing bootstrap chained servers at first run
LANTERN_YAML=$LANTERN_WRAPPER_DIR/lantern.yaml

LANTERN_USER_DIRECTORY=$HOME/.lantern
LANTERN_SOURCE_BINARY_HASH=$LANTERN_USER_DIRECTORY/bin/lantern.sha1
LANTERN_USER_BINARY=$LANTERN_USER_DIRECTORY/bin/lantern

# Checking if the source Lantern binary had any change.
if [ -f $LANTERN_SOURCE_BINARY_HASH ]; then
  # If the checksum does not match then it probably means that the source
  # binary got updated. See https://github.com/getlantern/lantern/issues/2670.
  sha1sum -c $LANTERN_SOURCE_BINARY_HASH || rm -f $LANTERN_USER_BINARY;
else
  # This was an old version that didn't saved verification sums.
  rm -f $LANTERN_USER_BINARY;
fi

# A local copy of the Lantern binary is preferred since it has the current
# user's writing permissions and it can be updated.
if [ ! -f $LANTERN_USER_BINARY ]; then
  # If there is no local copy, we use the original Lantern binary.
  mkdir -p $LANTERN_USER_DIRECTORY/bin
  echo "Copying files"
  cp $LANTERN_SOURCE_BINARY $LANTERN_USER_BINARY
  echo "Copying packaged yaml"
  cp $LANTERN_SOURCE_YAML $LANTERN_USER_DIRECTORY
  echo "Copying lantern.yaml"
  cp $LANTERN_YAML $LANTERN_USER_DIRECTORY
  sha1sum $LANTERN_SOURCE_BINARY > $LANTERN_SOURCE_BINARY_HASH
  chmod +x $LANTERN_USER_BINARY
fi

# Running Lantern with the given arguments.
exec "$LANTERN_USER_BINARY" "$@"
