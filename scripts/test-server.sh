#!/bin/bash

base_dir=`dirname $0`
port=9876

echo "Starting JSTD server at http://localhost:$port"
echo ""
echo "Please open the url above and capture one or more browsers."
echo ""
echo "For more info please see: http://code.google.com/p/js-test-driver/"

java -jar "$base_dir/../test/lib/jstestdriver/JsTestDriver.jar" --port $port --browserTimeout 20000
