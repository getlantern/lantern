// +build !android

package main

import (
	"log"

	"github.com/getlantern/osversion"
)

func main() {
	str, err := osversion.GetString()
	if err != nil {
		log.Fatalf("Error getting OS version: %v", err)
	}
	log.Println(str)

	version, err := osversion.GetSemanticVersion()
	if err != nil {
		log.Fatalf("Error getting OS version: %v", err)
	}

	log.Println(version)

	hstr, err := osversion.GetHumanReadable()
	if err != nil {
		log.Fatalf("Error getting OS version: %v", err)
	}

	log.Println(hstr)
}
