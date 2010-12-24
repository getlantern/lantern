#!/bin/sh

base_dir=`dirname $0`

tests=$1
if [[ $tests = "" ]]; then
  tests="all"
fi

java -jar "$base_dir/../test/lib/jstestdriver/JsTestDriver.jar" --config "$base_dir/../jsTestDriver.conf" --tests "$tests"
