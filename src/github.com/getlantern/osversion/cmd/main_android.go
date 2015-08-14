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
			log.Println("Error")
		}
		log.Println(str)

		str, err = osversion.GetHumanReadable()
		if err != nil {
			log.Println("Error")
		}
		log.Println(str)
	})
}
