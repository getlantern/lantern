// Command aws-gen-goendpoints parses a JSON description of the AWS endpoint
// discovery logic and generates a Go file which returns an endpoint.
//
//     aws-gen-goendpoints apis/_endpoints.json gen/endpoints/endpoints.go
package main

import (
	"os"

	"github.com/awslabs/aws-sdk-go/model"
)

func main() {
	in, err := os.Open(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer in.Close()

	var endpoints model.Endpoints
	if err := endpoints.Parse(in); err != nil {
		panic(err)
	}

	out, err := os.Create(os.Args[2])
	if err != nil {
		panic(err)
	}
	defer out.Close()

	if err := endpoints.Generate(out); err != nil {
		panic(err)
	}
}
