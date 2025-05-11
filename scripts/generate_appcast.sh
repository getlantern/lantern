#!/bin/bash

VERSION=$1
BUILD_VERSION=$2
DMG_URL=$3
DMG_SIZE=$(stat -c%s "$4")
PUB_DATE=$(date -R)

cat <<EOF > appcast.xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Lantern</title>
    <description>Latest updates for Lantern</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <sparkle:version>$BUILD_VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <pubDate>$PUB_DATE</pubDate>
      <enclosure
        url="$DMG_URL"
        sparkle:os="macos"
        length="$DMG_SIZE"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF