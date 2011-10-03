#!/usr/bin/env bash

./remoteLocalize.bash
pushd ..
mvn -Dtest=ResourceBundleTest test
popd 
