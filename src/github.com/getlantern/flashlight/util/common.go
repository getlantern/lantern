package util

import (
	"errors"
	"github.com/getlantern/golog"
	"os"
	"os/user"
	"path"
)

var (
	log = golog.LoggerFor("util")
)

type logger func(arg interface{})

func GetUserHomeDir() (string, error) {
	usr, err := user.Current()
	if err != nil {
		log.Errorf("Error locating user home directory %s", err)
		return "", err
	}
	lanternDir := path.Join(usr.HomeDir, ".lantern")
	// Create the ~/.lantern directory if it doesn't exist already
	exists, _ := DirExists(lanternDir)
	if !exists {
		err = os.Mkdir(lanternDir, 0755)
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
		err := "source exists, but it's not a directory"
		return false, errors.New(err)
	}

	return true, nil
}
