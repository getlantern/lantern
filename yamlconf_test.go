package yamlconf

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
	"github.com/getlantern/yaml"
)

const (
	FIXED_I       = 55
	ConfigSrvAddr = "localhost:31432"
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
		c.N.I = FIXED_I
	}
}

func TestFileAndUpdate(t *testing.T) {
	file, err := ioutil.TempFile("", "yamlconf_test_")
	if err != nil {
		t.Fatalf("Unable to create temp file: %s", err)
	}
	defer os.Remove(file.Name())

	m := &Manager{
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath:         file.Name(),
		FilePollInterval: pollInterval,
	}

	first, err := m.Start()
	if err != nil {
		t.Fatalf("Unable to start manager: %s", err)
	}

	assertSavedConfigEquals(t, file, &TestCfg{
		Version: 1,
		N: &Nested{
			I: FIXED_I,
		},
	})

	assert.Equal(t, &TestCfg{
		Version: 1,
		N: &Nested{
			I: FIXED_I,
		},
	}, first, "First config should contain correct data")

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		// Push updates

		// Push update with bad version file (this should not get emitted as an
		// updated config)
		saveConfig(t, file, &TestCfg{
			Version: 0,
			N: &Nested{
				S: "3",
				I: 3,
			},
		})

		// Wait for file update to get picked up
		time.Sleep(pollInterval * 2)

		// Push update to file
		saveConfig(t, file, &TestCfg{
			Version: 1,
			N: &Nested{
				S: "3",
				I: 3,
			},
		})

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
		Version: 1,
		N: &Nested{
			S: "3",
			I: 3,
		},
	}, updated, "Config from updated file should contain correct data")

	updated = m.Next()
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
	defer os.Remove(file.Name())

	poll := 0
	m := &Manager{
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath:         file.Name(),
		FilePollInterval: pollInterval,
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

	_, err = m.Start()
	if err != nil {
		t.Fatalf("Unable to start manager: %s", err)
	}

	updated := m.Next()

	assert.Equal(t, &TestCfg{
		Version: 2,
		N: &Nested{
			S: "Modified",
			I: FIXED_I,
		},
	}, updated, "Custom polled config should contain correct data")
}

func TestConfigServer(t *testing.T) {
	file, err := ioutil.TempFile("", "yamlconf_test_")
	if err != nil {
		t.Fatalf("Unable to create temp file: %s", err)
	}
	defer os.Remove(file.Name())

	m := &Manager{
		EmptyConfig: func() Config {
			return &TestCfg{}
		},
		FilePath:         file.Name(),
		FilePollInterval: pollInterval,
		ConfigServerAddr: ConfigSrvAddr,
	}

	_, err = m.Start()
	if err != nil {
		t.Fatalf("Unable to start manager: %s", err)
	}

	newNested := &Nested{
		S: "900",
		I: 900,
	}
	nny, err := yaml.Marshal(newNested)
	if err != nil {
		t.Fatalf("Unable to marshal new nested into yaml: %s", err)
	}

	_, err = http.Post(fmt.Sprintf("http://%s/N", ConfigSrvAddr), "text/yaml", bytes.NewReader(nny))
	assert.NoError(t, err, "POSTing to config server should succeed")

	updated := m.Next()

	assert.Equal(t, &TestCfg{
		Version: 2,
		N:       newNested,
	}, updated, "Nested should have been updated by POST")

	req, err := http.NewRequest("DELETE", fmt.Sprintf("http://%s/N/I", ConfigSrvAddr), bytes.NewReader(nny))
	if err != nil {
		t.Fatalf("Unable to construct DELETE request: %s", err)
	}
	_, err = (&http.Client{}).Do(req)
	assert.NoError(t, err, "DELETEing to config server should succeed")

	updated = m.Next()

	assert.Equal(t, &TestCfg{
		Version: 3,
		N: &Nested{
			S: newNested.S,
			I: FIXED_I,
		},
	}, updated, "Nested I should have reverted to default value after clearing")
}

func assertSavedConfigEquals(t *testing.T, file *os.File, expected *TestCfg) {
	b, err := yaml.Marshal(expected)
	if err != nil {
		t.Fatalf("Unable to marshal expected to yaml: %s", err)
	}
	bod, err := ioutil.ReadFile(file.Name())
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
