package util

import (
	"errors"
	"github.com/getlantern/golog"
	"github.com/mitchellh/go-homedir"
	"io/ioutil"
	"os"
	"path"
)

var (
	log = golog.LoggerFor("util")
)

type logger func(arg interface{})

// GetUserHomeDir() determines the user home directory using the go-homedir
// package which can be used in cross-compliation environments
func GetUserHomeDir() (string, error) {
	homedir, err := homedir.Dir()
	if err != nil {
		log.Errorf("Error locating user home directory %s", err)
		return "", err
	}
	lanternDir := path.Join(homedir, ".lantern")
	// Create the user home directory if it doesn't exist already
	exists, _ := DirExists(lanternDir)
	if !exists {
		err = os.Mkdir(lanternDir, 0777)
		if err != nil {
			log.Errorf("Error creating user home directory: %s", err)
		}
	}
	return lanternDir, err
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
