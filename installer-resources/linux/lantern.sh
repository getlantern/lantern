#!/bin/bash

# Lantern wrapper.
# Copyright (c) 2015. Lantern Team <team@getlantern.org>.

# Lantern could probably use this LANTERN_WRAPPER env var in the future.
export LANTERN_WRAPPER=$(readlink -f "$0")

LANTERN_WRAPPER_DIR=$(dirname "$LANTERN_WRAPPER")

# This is the original Lantern binary that came with the installer, it's
# probably out of date.
LANTERN_SOURCE_BINARY=$LANTERN_WRAPPER_DIR/lantern-binary

LANTERN_USER_DIRECTORY=$HOME/.lantern
LANTERN_USER_BINARY=$LANTERN_USER_DIRECTORY/bin/lantern

# A local copy of the Lantern binary is preferred since it can update by
# itself.
if [ ! -f $LANTERN_USER_BINARY ]; then
  # If there is no local copy, we use the original Lantern binary.
  mkdir -p $LANTERN_USER_DIRECTORY/bin
  cp $LANTERN_SOURCE_BINARY $LANTERN_USER_BINARY
  chmod +x $LANTERN_USER_BINARY
fi

# Running Lantern with the given arguments.
exec "$LANTERN_USER_BINARY" "$@"
