package appdir

import (
	"log"
	"testing"
)

func TestDisplayPaths(t *testing.T) {
	log.Println(General("MyApp"))
	log.Println(Logs("MyApp"))
}
