#!/usr/bin/env bash

LANTERN_DIR=`dirname $0`
$LANTERN_DIR/install.bash $* || exit
$LANTERN_DIR/quickRun.bash $*
