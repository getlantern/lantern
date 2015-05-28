#!/usr/bin/env bash
gocode close
sleep 0.5
echo "--------------------------------------------------------------------"
echo "Autocompletion tests..."
echo "--------------------------------------------------------------------"
./run.rb
sleep 0.5
gocode close
