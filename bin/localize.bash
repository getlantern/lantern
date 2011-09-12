#!/usr/bin/env bash
function die() {
    echo $*
    exit 1
}


cd /home/lantern/lantern
rm po/*
rm -rf src/main/resources/app

# We tend to be modifying this file if we're running this script a lot, so kill
# it on the server to avoid git conflicts.
rm bin/localize.bash
git pull origin master
xgettext -ktrc -ktr -kmarktr -ktrn:1,2 -o po/keys.pot $(find . -name "*.java")

locales=("en" "zh" "zh_CN")
for l in ${locales[@]}
do
  echo "Processing locale: $l"
  touch po/$l.po
  msgmerge -U po/$l.po po/keys.pot || die "Could not merge $l"
  echo "Done merging $l"
  msgfmt --java2 -d src/main/resources -r app.i18n.Messages -l $l po/$l.po || die "Could not format $l"
  echo "Done processing $l"
done

