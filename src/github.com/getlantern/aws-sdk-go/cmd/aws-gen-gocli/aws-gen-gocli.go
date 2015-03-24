// Command aws-gen-gocli parses a JSON description of an AWS API and generates a
// Go file containing a client for the API.
//
//     aws-gen-gocli EC2 apis/ec2/2014-10-01.api.json gen/ec2/ec2.go
package main

import (
	"fmt"
	"os"

	"github.com/getlantern/aws-sdk-go/model"
)

func main() {
	in, err := os.Open(os.Args[2])
	if err != nil {
		panic(err)
	}
	defer in.Close()

	out, err := os.Create(os.Args[3])
	if err != nil {
		panic(err)
	}
	defer out.Close()

	if err := model.Load(os.Args[1], in); err != nil {
		panic(err)
	}

	if err := model.Generate(out); err != nil {
		fmt.Fprintf(os.Stderr, "error generating %s\n", os.Args[3])
		panic(err)
	}
}
