#!/usr/bin/env bash
go run genconfig.go -blacklist="blacklist.txt" -domains="domains.txt" -proxiedsites="proxiedsites" -fallbacks="{default: nl, cn: jp}"
