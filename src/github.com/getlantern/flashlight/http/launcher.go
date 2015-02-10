package http

import (
	"github.com/skratchdot/open-golang/open"
)

const (
	UIAddress = "http://127.0.0.1:16785/app"
)

func openUI() {
	err := open.Run(UIAddress)
	if err != nil {
		log.Fatalf("Could not open UI!")
	}
}
