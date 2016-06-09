#!/bin/bash

influx -execute "drop database lantern" || die "Unable to drop database"
influx -execute "drop user test" || die "Unable to drop user"
