#!/usr/bin/env bash
cd /home/lantern/lantern
xgettext -ktrc -ktr -kmarktr -ktrn:1,2 -o po/keys.pot $(find . -name "*.java")

locales=("en" "zh_CN") 
for l in ${locales[@]}
do 
  echo "Processing locale: $l"
  touch po/$l.po
  msgmerge -U po/$l.po po/keys.pot
  msgfmt --java2 -d src/main/resources -r app.i18n.Messages -l $l po/$l.po
done

