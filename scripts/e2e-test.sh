#!/bin/bash

BASE_DIR=`dirname $0`

java -jar "$BASE_DIR/../test/lib/jstestdriver/JsTestDriver.jar" \
     --config "$BASE_DIR/../config/jsTestDriver-scenario.conf" \
     --basePath "$BASE_DIR/.." \
     --tests all --reset
