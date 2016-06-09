#!/bin/bash

find_files() {
  find . -not \( \
      \( \
        -name 'vendor' \
      \) -prune \
    \) -name '*.go'
}

bad_files=$(find_files | xargs gofmt -s -l)
if [[ -n "${bad_files}" ]]; then
    echo "!!! gofmt needs to be run on the following files: "
    echo "${bad_files}"
    exit 1
fi
