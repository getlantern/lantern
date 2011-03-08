#!/bin/bash

base_dir=`dirname $0`
port=9876

echo "Starting JsTestDriver Server (http://code.google.com/p/js-test-driver/)"
echo "Please open the following url and capture one or more browsers:"
echo "http://localhost:$port"

java -jar "$base_dir/../test/lib/jstestdriver/JsTestDriver.jar" --port $port --browserTimeout 20000 --config "$base_dir/../config/jsTestDriver.conf" --basePath "$base_dir/.."