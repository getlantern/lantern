package main

import (
	"fmt"
	"path/filepath"

	"github.com/getlantern/golog"
	"github.com/getlantern/pac"
)

var log = golog.LoggerFor("example")

func main() {
	helperFullPath := "pac-cmd"
	iconFullPath, _ := filepath.Abs("./icon.png")
	log.Debugf("Using icon at %v", iconFullPath)
	err := pac.EnsureHelperToolPresent(helperFullPath, "Input your password and save the world!", iconFullPath)
	if err != nil {
		fmt.Printf("Error EnsureHelperToolPresent: %s\n", err)
		return
	}
	err = pac.On("localhost:12345/pac")
	if err != nil {
		fmt.Printf("Error set proxy: %s\n", err)
		return
	}
	fmt.Println("proxy set, Enter continue...")
	var i int
	fmt.Scanf("%d\n", &i)
	pac.Off("localhost:12345/pac")
}
