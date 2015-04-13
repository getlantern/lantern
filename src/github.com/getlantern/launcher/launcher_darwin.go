// Package launcher configures Lantern to run on system start
package launcher

import (
	"bytes"
	"io/ioutil"
	"text/template"

	"github.com/getlantern/appdir"
	"github.com/getlantern/golog"
)

const (
	// OS X plist file
	LaunchdPlistFile = `Library/LaunchAgents/org.getlantern.plist`

	LaunchdPlist = `<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
		"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>Label</key>
		<string>org.getlantern</string>
		<key>ProgramArguments</key>
		<array>
		<string>/Applications/Lantern.app/Contents/MacOS/lantern</string>
		</array>
		<key>RunAtLoad</key>
        <{{.RunAtLoad}}/>
	</dict>
	</plist>`
)

var (
	log = golog.LoggerFor("launcher")
)

type Plist struct {
	RunAtLoad bool
}

func CreateLaunchFile(autoLaunch bool) {
	var err error
	var content bytes.Buffer
	fname := appdir.InHomeDir(LaunchdPlistFile)

	// Create plist template and set RunAtLoad property
	t := template.Must(template.New("LaunchdPlist").Parse(LaunchdPlist))

	err = t.Execute(&content, &Plist{RunAtLoad: autoLaunch})
	if err != nil {
		log.Errorf("Error writing plist template: %q", err)
		return
	}

	if err = ioutil.WriteFile(fname, content.Bytes(), 0755); err != nil {
		log.Errorf("Error writing to launchd plist file: %q", err)
	}
}
