package i18n

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestTranslate(t *testing.T) {
	assertTranslation(t, "", "HELLO")
	if err := UseOSLocale(); err != nil {
		log.Debugf("Unable to detect and use OS locale: %v", err)
	}
	assertTranslation(t, "I speak America English!", "ONLY_IN_EN_US")
	assertTranslation(t, "I speak Generic English!", "ONLY_IN_EN")
	assertTranslation(t, "", "NOT_EXISTED")

	SetMessagesDir("not-existed-dir")
	err := SetLocale("en_US")
	assert.Error(t, err, "should error if dir is not existed")

	SetMessagesDir("locale")
	assert.Error(t, SetLocale("e0"), "should error on malformed locale")
	assert.Error(t, SetLocale("e0-DO"), "should error on malformed locale")
	assert.Error(t, SetLocale("e0-DO.C"), "should error on malformed locale")
	assert.NoError(t, SetLocale("en"), "should change locale")
	if assert.NoError(t, SetLocale("en_US"), "should change locale") {
		// formatting
		assertTranslation(t, "Hello An Argument!", "HELLO", "An Argument")
		assertTranslation(t, "", "NOT_EXISTED", "extra args")
	}
	if assert.NoError(t, SetLocale("zh_CN"), "should change locale") {
		assertTranslation(t, "An Argument你好!", "HELLO", "An Argument")
		// fallbacks
		assertTranslation(t, "I speak Mandarin!", "ONLY_IN_ZH_CN")
		assertTranslation(t, "I speak Chinese!", "ONLY_IN_ZH")
		assertTranslation(t, "I speak America English!", "ONLY_IN_EN_US")
		assertTranslation(t, "I speak Generic English!", "ONLY_IN_EN")
	}
}

func TestReadFromMemory(t *testing.T) {
	fromMemory := func(path string) ([]byte, error) {
		switch path {
		case "en_US.json":
			return []byte(`{"HELLO": "Hello %s!"}`), nil
		case "zh_CN.json":
			return []byte(`{"ONLY_IN_ZH": "I speak Chinese!"}`), nil
		}
		return nil, nil
	}
	SetMessagesFunc(fromMemory)
	if assert.NoError(t, SetLocale("en_US"), "should load en_US from memory") {
		assertTranslation(t, "", "ONLY_IN_ZH")
	}
	if assert.NoError(t, SetLocale("zh_CN"), "should load zh_CN from memory") {
		assertTranslation(t, "I speak Chinese!", "ONLY_IN_ZH")
	}
}

func TestGoroutine(t *testing.T) {
	SetMessagesDir("locale")
	if err := SetLocale("en_US"); err != nil {
		log.Debugf("Unable to set en_US locale: %v", err)
	}
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		assertTranslation(t, "I speak America English!", "ONLY_IN_EN_US")
		wg.Done()
	}()
	go func() {
		assertTranslation(t, "I speak Generic English!", "ONLY_IN_EN")
		wg.Done()
	}()
	wg.Wait()
}

func assertTranslation(t *testing.T, expected string, key string, args ...interface{}) {
	if s := T(key, args...); s != expected {
		t.Errorf("Expect T(\"%s\") to be \"%s\", got \"%s\"\n", key, expected, s)
	}
}
