package yamlconf

import (
	"bytes"
	"crypto/cipher"
	"fmt"
	"io"
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

	defaultConfig = &TestCfg{
		Version: 0,
		N: &Nested{
			S: "3",
		},
	}
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

func TestNoFileDefault(t *testing.T) {
	file := tempConfig(t)
	defer removeTempConfig(t, file)

	err := os.Remove(file.Name())
	if !assert.NoError(t, err, "Unable to clear temp file") {
		return
	}

	m := &Manager{
		DefaultConfig: func() (Config, error) {
			return defaultConfig, nil
		},
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath:  file.Name(),
		Obfuscate: true,
	}

	doTest(t, m, file, true)
}

func TestNoFileNoDefault(t *testing.T) {
	file := tempConfig(t)
	defer removeTempConfig(t, file)

	err := os.Remove(file.Name())
	if !assert.NoError(t, err, "Unable to clear temp file") {
		return
	}

	m := &Manager{
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath:  file.Name(),
		Obfuscate: true,
	}

	_, err = m.Init()
	assert.Error(t, err, "Manager should have failed to initialize with no file")
}

func TestBadFilePlain(t *testing.T) {
	doTestBadFile(t, false)
}

func TestBadFileObfuscated(t *testing.T) {
	doTestBadFile(t, true)
}

func doTestBadFile(t *testing.T, obfuscate bool) {
	file := tempConfig(t)
	defer removeTempConfig(t, file)

	saveConfig(t, file, obfuscate, &TestCfg{
		Version: 0,
		N:       &Nested{},
	})

	m := &Manager{
		ValidateConfig: func(_cfg Config) error {
			cfg, _ := _cfg.(*TestCfg)
			if cfg.N.S == "" {
				return fmt.Errorf("Missing S!")
			}
			return nil
		},
		DefaultConfig: func() (Config, error) {
			return defaultConfig, nil
		},
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath: file.Name(),
	}

	doTest(t, m, file, obfuscate)
}

func TestGoodFileObfuscated(t *testing.T) {
	doTestGoodFile(t, true)
}

func TestGoodFilePlain(t *testing.T) {
	doTestGoodFile(t, false)
}

func doTestGoodFile(t *testing.T, obfuscate bool) {
	file := tempConfig(t)
	defer removeTempConfig(t, file)

	saveConfig(t, file, obfuscate, defaultConfig)

	m := &Manager{
		ValidateConfig: func(cfg Config) error {
			return nil
		},
		DefaultConfig: func() (Config, error) {
			return &TestCfg{}, nil
		},
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath: file.Name(),
	}

	doTest(t, m, file, obfuscate)
}

func doTest(t *testing.T, m *Manager, file *os.File, obfuscate bool) {
	m.Obfuscate = obfuscate
	first, err := m.Init()
	if err != nil {
		t.Fatalf("Unable to Init manager: %s", err)
	}

	defaultConfigWithDefaults := &TestCfg{
		Version: 1,
		N: &Nested{
			S: "3",
			I: I,
		},
	}
	assertSavedConfigEquals(t, m, file, defaultConfigWithDefaults, obfuscate)

	assert.Equal(t, defaultConfigWithDefaults, first, "First config should contain correct data")

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
	file := tempConfig(t)
	defer removeTempConfig(t, file)

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

	_, err := m.Init()
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

func tempConfig(t *testing.T) *os.File {
	file, err := ioutil.TempFile("", "yamlconf_test_")
	if err != nil {
		t.Fatalf("Unable to create temp file: %s", err)
	}
	return file
}

func removeTempConfig(t *testing.T, file *os.File) {
	err := os.Remove(file.Name())
	if err != nil {
		t.Logf("Unable to remove file: %v", err)
	}
}

func assertSavedConfigEquals(t *testing.T, m *Manager, file *os.File, expected *TestCfg, obfuscate bool) {
	b, err := yaml.Marshal(expected)
	if err != nil {
		t.Fatalf("Unable to marshal expected to yaml: %s", err)
	}
	infile, err := os.Open(file.Name())
	if !assert.NoError(t, err, "Unable to open file") {
		return
	}
	defer infile.Close()
	var in io.Reader = infile
	if obfuscate {
		stream, err2 := obfuscationStream()
		if !assert.NoError(t, err2, "Unable to get obfuscation stream") {
			return
		}
		in = &cipher.StreamReader{S: stream, R: infile}
	}
	bod, err := ioutil.ReadAll(in)
	if err != nil {
		t.Errorf("Unable to read config from disk: %s", err)
	}
	if !bytes.Equal(b, bod) {
		t.Errorf("Saved config doesn't equal expected.\n---- Expected ----\n%s\n\n---- On Disk ----:\n%s\n\n", string(b), string(bod))
	}
}

func saveConfig(t *testing.T, file *os.File, obfuscate bool, updated *TestCfg) {
	b, err := yaml.Marshal(updated)
	if err != nil {
		t.Fatalf("Unable to marshal updated to yaml: %s", err)
	}
	var out io.Writer = file
	if obfuscate {
		stream, err2 := obfuscationStream()
		if !assert.NoError(t, err2, "Unable to get obfuscation stream") {
			return
		}
		out = &cipher.StreamWriter{S: stream, W: file}
	}
	_, err = out.Write(b)
	if err == nil {
		err = file.Sync()
	}
	if err != nil {
		t.Fatalf("Unable to save test config: %s", err)
	}
}
