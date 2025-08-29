#!/usr/bin/env bash

groups=("group.getlantern.lantern" "group.ACZRKC3LQ9.org.getlantern.lantern")

for group in "${groups[@]}"; do
  rm -rf "/private/var/root/Library/GroupContainersAlias$group"
  rm -rf "$HOME/Library/GroupContainersAlias/$group"
done

rm -rf "/Users/Shared/Lantern"
rm -rf "$HOME/Library/Application Support/Lantern"
rm -rf "$HOME/Library/Application Support/org.getlantern.lantern"
rm -rf "$HOME/Library/Logs/Lantern"
rm -rf "$HOME/Library/Containers/org.getlantern.*"
