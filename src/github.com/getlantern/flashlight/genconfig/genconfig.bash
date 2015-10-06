#!/usr/bin/env bash
go run genconfig.go -blacklist="blacklist.txt" -masquerades="masquerades.txt" -proxiedsites="proxiedsites" -fallbacks="fallbacks.yaml"
