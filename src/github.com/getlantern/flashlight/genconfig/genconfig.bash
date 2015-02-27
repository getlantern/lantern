#!/usr/bin/env bash
go build
./genconfig -blacklist="blacklist.txt" -domains="domains.txt" -proxiedsites="proxiedsites"
