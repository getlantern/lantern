#!/bin/bash

influx -execute "drop continuous query combined_1m ON lantern" || die "Unable to drop continuous query 1"
influx -execute "drop continuous query proxy_1m ON lantern" || die "Unable to drop continuous query 1"
influx -execute "drop continuous query client_1m ON lantern" || die "Unable to drop continuous query 1"
