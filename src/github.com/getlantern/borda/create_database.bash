#!/bin/bash

function die() {
  echo $*
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1
}

# Create a database
influx -execute 'create database lantern' || die 'Unable to create database'
influx -database lantern -execute 'CREATE RETENTION POLICY short ON lantern DURATION 1h REPLICATION 1 DEFAULT' || die 'Unable to create retention policy'

# Create the user to write to database
influx -execute "create user test with password 'test'" || die 'Unable to create user'
influx -execute 'grant write on lantern to test' || die 'Unable to grant access to user'

# Create some continuous queries that downsample to 1m intervals but resample going back 2m so that we don't miss stuff from lagging inserts
influx -database lantern -execute 'CREATE CONTINUOUS QUERY combined_1m ON lantern RESAMPLE FOR 2m BEGIN SELECT sum(client_success_count) as client_success_count, sum(client_error_count) as client_error_count, sum(client_error_count) / sum(client_success_count) as client_error_rate, sum(proxy_success_count) as proxy_success_count, sum(proxy_error_count) as proxy_error_count, median(load_avg) as median_load_avg INTO lantern."default".combined_1m FROM combined GROUP BY time(1m), client, proxy, client_error, proxy_error END;' || die 'Unable to create continuous query 1'
influx -database lantern -execute 'CREATE CONTINUOUS QUERY proxy_1m ON lantern RESAMPLE FOR 2m BEGIN SELECT sum(client_success_count) as client_success_count, sum(client_error_count) as client_error_count, sum(client_error_count) / sum(client_success_count) as client_error_rate, sum(proxy_success_count) as proxy_success_count, sum(proxy_error_count) as proxy_error_count, sum(proxy_error_count) / sum(proxy_success_count) as proxy_error_rate, median(load_avg) as median_load_avg INTO lantern."default".proxy_1m FROM combined GROUP BY time(1m), proxy END;' || die 'Unable to create continuous query 2'
influx -database lantern -execute 'CREATE CONTINUOUS QUERY client_1m ON lantern RESAMPLE FOR 2m BEGIN SELECT sum(client_success_count) as client_success_count, sum(client_error_count) as client_error_count, sum(client_error_count) / sum(client_success_count) as client_error_rate, sum(proxy_success_count) as proxy_success_count, sum(proxy_error_count) as proxy_error_count, sum(proxy_error_count) / sum(proxy_success_count) as proxy_error_rate INTO lantern."default".client_1m FROM combined GROUP BY time(1m), client END;' || die 'Unable to create continuous query 3'
