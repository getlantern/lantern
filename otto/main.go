package main

import (
	"fmt"
	"flag"
	"io/ioutil"
	"os"
	"github.com/robertkrimen/otto"
)

func main() {
	flag.Parse()
	var script []byte
	var err error
	filename := flag.Arg(0)
	if filename == "" || filename == "-" {
		script, err = ioutil.ReadAll(os.Stdin)
		if err != nil {
			fmt.Printf("Can't read stdin: %v\n", err)
			os.Exit(64)
		}
	} else {
		script, err = ioutil.ReadFile(filename)
		if err != nil {
			fmt.Printf("Can't open file \"%v\": %v\n", filename, err)
			os.Exit(64)
		}
	}
	Otto := otto.New()
	_, err = Otto.Run(string(script))
	if err != nil {
		fmt.Println(err)
		os.Exit(64)
	}
}
