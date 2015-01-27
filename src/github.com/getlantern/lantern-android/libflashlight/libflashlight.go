// main package holds references to the go_bindings package and is based on
// instructions from http://godoc.org/golang.org/x/mobile/cmd/gobind
package main

import (
	_ "github.com/getlantern/lantern-android/libflashlight/bindings/go_bindings"
	"golang.org/x/mobile/app"
	_ "golang.org/x/mobile/bind/java"
)

func main() {
	app.Run(app.Callbacks{})
}
