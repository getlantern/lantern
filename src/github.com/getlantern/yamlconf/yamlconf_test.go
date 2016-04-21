package yamlconf

import (
	"bytes"
	"crypto/cipher"
	"fmt"
	"io/ioutil"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/getlantern/yaml"
	"github.com/stretchr/testify/assert"
)

const (
	I = 55
)

var (
	pollInterval = 100 * time.Millisecond
)

type TestCfg struct {
	Version int
	N       *Nested
}

type Nested struct {
	S string
	I int
}

func (c *TestCfg) GetVersion() int {
	return c.Version
}

func (c *TestCfg) SetVersion(version int) {
	c.Version = version
}

func (c *TestCfg) ApplyDefaults() {
	if c.N == nil {
		c.N = &Nested{}
	}
	if c.N.I == 0 {
		c.N.I = I
	}
}

func TestFileAndUpdate(t *testing.T) {
	file, err := ioutil.TempFile("", "yamlconf_test_")
	if err != nil {
		t.Fatalf("Unable to create temp file: %s", err)
	}
	defer func() {
		if err2 := os.Remove(file.Name()); err2 != nil {
			t.Fatalf("Unable to remove file: %v", err2)
		}
	}()

	// Create an initial config on disk
	saveConfig(t, file, &TestCfg{
		Version: 0,
		N: &Nested{
			S: "3",
		},
	})

	m := &Manager{
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath:  file.Name(),
		Obfuscate: true,
	}

	first, err := m.Init()
	if err != nil {
		t.Fatalf("Unable to Init manager: %s", err)
	}

	assertSavedConfigEquals(t, m, file, &TestCfg{
		Version: 1,
		N: &Nested{
			S: "3",
			I: I,
		},
	})

	assert.Equal(t, &TestCfg{
		Version: 1,
		N: &Nested{
			S: "3",
			I: I,
		},
	}, first, "First config should contain correct data")

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		// Push updates

		// Wait for file update to get picked up
		time.Sleep(pollInterval * 2)

		// Perform update programmatically
		err := m.Update(func(cfg Config) error {
			tc := cfg.(*TestCfg)
			tc.N.S = "4"
			tc.N.I = 4
			return nil
		})
		if err != nil {
			t.Fatalf("Unable to issue first update: %s", err)
		}

		wg.Done()
	}()

	updated := m.Next()
	assert.Equal(t, &TestCfg{
		Version: 2,
		N: &Nested{
			S: "4",
			I: 4,
		},
	}, updated, "Config from programmatic update should contain correct data, including updated version")

	wg.Wait()
}

func TestCustomPoll(t *testing.T) {
	file, err := ioutil.TempFile("", "yamlconf_test_")
	if err != nil {
		t.Fatalf("Unable to create temp file: %s", err)
	}
	defer func() {
		if err2 := os.Remove(file.Name()); err2 != nil {
			t.Fatalf("Unable to remove file: %s", err2)
		}
	}()

	poll := 0
	m := &Manager{
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath: file.Name(),
		CustomPoll: func(currentCfg Config) (func(cfg Config) error, time.Duration, error) {
			defer func() {
				poll = poll + 1
			}()
			switch poll {
			case 0:
				// Return an error on the poll
				return nil, 10 * time.Millisecond, fmt.Errorf("I don't wanna poll")
			case 1:
				// Return an error in the mutator
				return func(cfg Config) error {
					return fmt.Errorf("I don't wanna mutate")
				}, 10 * time.Millisecond, nil
			default:
				// Return a good mutator
				return func(cfg Config) error {
					tc := cfg.(*TestCfg)
					tc.N.S = "Modified"
					return nil
				}, 100 * time.Hour, nil
			}
		},
	}

	_, err = m.Init()
	m.StartPolling()
	if err != nil {
		t.Fatalf("Unable to init manager: %s", err)
	}
	m.StartPolling()

	updated := m.Next()

	assert.Equal(t, &TestCfg{
		Version: 2,
		N: &Nested{
			S: "Modified",
			I: I,
		},
	}, updated, "Custom polled config should contain correct data")
}

func assertSavedConfigEquals(t *testing.T, m *Manager, file *os.File, expected *TestCfg) {
	b, err := yaml.Marshal(expected)
	if err != nil {
		t.Fatalf("Unable to marshal expected to yaml: %s", err)
	}
	stream, err := m.obfuscationStream()
	if !assert.NoError(t, err, "Unable to get obfuscation stream") {
		return
	}
	infile, err := os.Open(file.Name())
	if !assert.NoError(t, err, "Unable to open file") {
		return
	}
	defer infile.Close()
	bod, err := ioutil.ReadAll(&cipher.StreamReader{S: stream, R: infile})
	if err != nil {
		t.Errorf("Unable to read config from disk: %s", err)
	}
	if !bytes.Equal(b, bod) {
		t.Errorf("Saved config doesn't equal expected.\n---- Expected ----\n%s\n\n---- On Disk ----:\n%s\n\n", string(b), string(bod))
	}
}

func saveConfig(t *testing.T, file *os.File, updated *TestCfg) {
	b, err := yaml.Marshal(updated)
	if err != nil {
		t.Fatalf("Unable to marshal updated to yaml: %s", err)
	}
	err = ioutil.WriteFile(file.Name(), b, 0644)
	if err != nil {
		t.Fatalf("Unable to save test config: %s", err)
	}
}
