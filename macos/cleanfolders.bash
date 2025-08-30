#!/usr/bin/env bash

set -e

groups=("group.getlantern.lantern" "group.ACZRKC3LQ9.org.getlantern.lantern")

for group in "${groups[@]}"; do
  rm -rfv /private/var/root/Library/Group\ Containers/$group
  rm -rfv $HOME/Library/Group\ Containers/$group
done

paths=(
  /Users/Shared/Lantern
  $HOME/Library/Application Support/Lantern
  $HOME/Library/Application Support/org.getlantern.lantern
  $HOME/Library/Logs/Lantern
)

for path in "${paths[@]}"; do
  rm -rfv "$path"
done
rm -rfv $HOME/Library/Containers/org.getlantern.*
