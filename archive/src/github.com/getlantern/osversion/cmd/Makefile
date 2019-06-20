linux:
	CGO_ENABLED=1 GOOS=linux GOARCH=386 go run /src/github.com/getlantern/osversion/cmd

windows:
	CGO_ENABLED=1 GOOS=windows GOARCH=386 go run /src/github.com/getlantern/osversion/cmd

android:
	GOOS=android GOARCH=arm gomobile build -target=android github.com/getlantern/osversion/cmd && \
  adb install -r cmd.apk
