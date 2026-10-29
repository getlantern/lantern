package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"os"
	"strconv"

	"gopkg.in/yaml.v3"
)

// Capture only the identity initialized by the released app on this disposable VM.
func captureLegacy(settingsPath, deviceID, expectedPath string) error {
	file, err := os.Open(settingsPath)
	if err != nil {
		return errors.New("legacy identity unavailable")
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > 64*1024 {
		return errors.New("invalid legacy settings file")
	}
	var settings struct {
		UserID     int64   `yaml:"userID"`
		Token      string  `yaml:"userToken"`
		Locale     *string `yaml:"lang"`
		AutoReport *bool   `yaml:"autoReport"`
		ProxyAll   *bool   `yaml:"proxyAll"`
		AutoLaunch *bool   `yaml:"autoLaunch"`
	}
	decoder := yaml.NewDecoder(io.LimitReader(file, 64*1024+1))
	if decoder.Decode(&settings) != nil || decoder.Decode(new(any)) != io.EOF {
		return errors.New("invalid legacy identity")
	}
	expected := Expected{SchemaVersion: 1, AccountEnvironment: "prod", UserID: strconv.FormatInt(settings.UserID, 10),
		Token: settings.Token, DeviceID: deviceID, Locale: settings.Locale, AutoReport: settings.AutoReport,
		ProxyAll: settings.ProxyAll, AutoLaunch: settings.AutoLaunch, UserLevel: "free"}
	data, err := json.Marshal(expected)
	if err != nil {
		return errors.New("invalid legacy identity")
	}
	if _, err := decodeExpected(bytes.NewReader(data), "prod"); err != nil {
		return err
	}
	// The harness checks this existing file's private ACL before invoking the probe.
	output, err := os.OpenFile(expectedPath, os.O_WRONLY|os.O_TRUNC, 0)
	if err != nil {
		return errors.New("private fixture unavailable")
	}
	_, writeErr := output.Write(data)
	return errors.Join(writeErr, output.Close())
}
