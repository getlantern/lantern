package main

import (
	"log"

	"github.com/getlantern/osversion"

	"golang.org/x/mobile/app"
)

func main() {
	// checkNetwork runs only once when the app first loads.
	app.Main(func(a app.App) {
		str, err := osversion.GetString()
		if err != nil {
			log.Printf("Error in osversion.GetString: %v", err)
		}
		log.Println(str)

		semVer, err := osversion.GetSemanticVersion()
		if err != nil {
			log.Printf("Error in osversion.GetSemanticVersion: %v", err)
		}
		log.Println(semVer.String())

		str, err = osversion.GetHumanReadable()
		if err != nil {
			log.Printf("Error in osversion.GetHumanReadable: %v", err)
		}
		log.Println(str)
	})
}
