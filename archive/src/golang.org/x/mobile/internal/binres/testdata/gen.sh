#! /usr/bin/sh

# version of build-tools tests run against
AAPT=${ANDROID_HOME}/build-tools/23.0.1/aapt

# minimum version of android api for resource identifiers supported
APIJAR=${ANDROID_HOME}/platforms/android-15/android.jar

for f in *.xml; do
	cp "$f" AndroidManifest.xml
	"$AAPT" p -M AndroidManifest.xml -I "$APIJAR" -F tmp.apk
	unzip -qq -o tmp.apk
	mv AndroidManifest.xml "${f:0:-3}bin"
	rm tmp.apk
done
