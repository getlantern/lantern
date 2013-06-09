#!/usr/bin/env bash

echo "Running at path $1"
sudo dpkg -i $1 || echo "Error installing deb file"
echo "Finished installing deb at $1"
