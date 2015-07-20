// Provide simple Windows OS interface to manipulate windows registry, environment variables, default paths and windows services from Golang lenguaje
//
package gowin 

import (
	"os"
)

// Use to read value from windows environment variables by name
func GetEnvVar(name string)(val string){
	val = os.Getenv(name)
	return
}

// Use to write value on windows environment variable by name
func WriteEnvVar(name, val string)(err error){
	err = os.Setenv(name, val)
	return
}
