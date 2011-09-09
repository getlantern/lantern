#!/usr/bin/env bash
cd /home/lantern/lantern
xgettext -ktrc -ktr -kmarktr -ktrn:1,2 -o po/keys.pot $(find . -name "*.java")

