#!/bin/bash

function die() {
  echo $*
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1
}

function query() {
  echo ""
  echo "******** $1 ********"
  echo ""
  echo "$2"
  echo ""
  influx -database lantern -execute "$2" || die "Unable to run query $2"
  echo ""
}

#query "This query shows the raw data" \
#      'select * from combined'

query "This query shows the raw data downsampled to 1m" \
      'select * from "default".combined_1m'

query "This query shows the downsampled data grouped by client. Notice how it becomes possible to correlate client and proxy errors" \
      'select * from "default".combined_1m group by client'

query "This query shows how to capture aggregate data per proxy" \
      'select * from "default".proxy_1m'

query "This query shows how to capture aggregate data per client" \
      'select * from "default".client_1m'
