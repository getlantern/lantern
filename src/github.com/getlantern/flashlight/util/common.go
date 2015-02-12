package util

import (
	"errors"
	"fmt"
	"github.com/getlantern/golog"
	"io/ioutil"
	"os"
	"os/user"
)

var (
	log = golog.LoggerFor("util")
)

type logger func(arg interface{})

// Based on https://github.com/getlantern/lantern-go/blob/master/src/lantern/config/config.go

// determineConfigDir() determines where to load the config by checking the
// command line and defaulting to ~/.lantern.
func DetermineConfigDir() string {
	usr, err := user.Current()
	if err != nil {
		fmt.Errorf("Error location user home directory %v", err)
	}
	return usr.HomeDir + "/.lantern"
}

func Check(e error, log logger, msg string) {
	if e != nil {
		log(msg)
	}
}

func FileExists(fileName string) (bool, error) {
	_, err := os.Stat(fileName)
	return err == nil, err
}

func DirExists(dirName string) (bool, error) {
	src, err := os.Stat(dirName)
	if err != nil {
		return false, err
	}

	if !src.IsDir() {
		err := "UI source exists, but it's not a directorY"
		return false, errors.New(err)
	}

	return true, nil
}

func LoadTemplate(name string) string {
	bytes, err := ioutil.ReadFile(name)
	if err != nil {
		log.Errorf("Unable to load template %s: %s", name, err)
	}
	return string(bytes)
}
