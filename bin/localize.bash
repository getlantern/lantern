#!/usr/bin/env bash
cd /home/lantern/lantern
xgettext -ktrc -ktr -kmarktr -ktrn:1,2 -o po/keys.pot $(find . -name "*.java")
touch po/en.po
msgmerge -U po/en.po po/keys.pot
msgfmt --java2 -d src/main/resources -r app.i18n.Messages -l en po/en.po
