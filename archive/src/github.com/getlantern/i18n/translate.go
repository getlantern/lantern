package i18n

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"regexp"
	"strings"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/jibber_jabber"
)

// ReadFunc is the func provided to SetMessagesFunc which returns the byte
// sequence given a file name
type ReadFunc func(fileName string) ([]byte, error)

var (
	localeRegexp  string   = "^[a-z]{2}([_-][A-Z]{2}){0,1}$"
	log                    = golog.LoggerFor("i18n")
	readFunc      ReadFunc = makeReadFunc("locale")
	defaultLocale string   = "en_US"
	defaultLang   string   = "en"
	trMutex       sync.RWMutex
	// read from a nil map is ok, so leave it uninitialized here
	trMap map[string]string
)

// T translates the given key into a message based on the current locale,
// formatting the string using the supplied (optional) args. This method will
// fall back to other locales if the key isn't defined for the current locale.
// The search order (with examples) is as follows:
//
//   1. current locale        (zh_CN)
//   2. lang only             (zh)
//   3. default locale        (en_US)
//   4. lang only of default  (en)
//
func T(key string, args ...interface{}) string {
	trMutex.RLock()
	defer trMutex.RUnlock()
	s := trMap[key]
	// Format string
	if s != "" && len(args) > 0 {
		s = fmt.Sprintf(s, args...)
	}

	return s
}

// SetMessagesDir sets the directory from which to load translations
// if they are not under the default directory 'locale'
func SetMessagesDir(d string) {
	readFunc = makeReadFunc(d)
}

func makeReadFunc(d string) ReadFunc {
	return func(p string) (buf []byte, err error) {
		fileName := path.Join(d, p)
		var f *os.File
		if f, err = os.Open(fileName); err != nil {
			err = fmt.Errorf("Error open file %s: %s", fileName, err)
			return
		}
		defer func() {
			if err := f.Close(); err != nil {
				log.Debugf("Unable to close file: %v", err)
			}
		}()
		if buf, err = ioutil.ReadAll(f); err != nil {
			err = fmt.Errorf("Error read file %s: %s", fileName, err)
		}
		return
	}
}

// SetMessagesFunc tells i18n to read translations through ReadFunc
func SetMessagesFunc(f ReadFunc) {
	readFunc = f
}

// UseOSLocale detect OS locale for current user and let i18n to use it
func UseOSLocale() error {
	userLocale, err := jibber_jabber.DetectIETF()
	if err != nil || userLocale == "C" {
		userLocale = defaultLocale
	}
	log.Tracef("Using OS locale of current user: %v", userLocale)
	return SetLocale(userLocale)
}

// SetLocale sets the current locale to the given value. If the locale is not in
// a valid format, this function will return an error and leave the current
// locale as is.
func SetLocale(locale string) error {
	if matched, _ := regexp.MatchString(localeRegexp, locale); !matched {
		return fmt.Errorf("Malformated locale string %s", locale)
	}
	locale = strings.Replace(locale, "-", "_", -1)
	parts := strings.Split(locale, "_")
	lang := parts[0]
	log.Debugf("Setting locale %v", locale)
	newTrMap := make(map[string]string)
	mergeLocaleToMap(newTrMap, defaultLang)
	mergeLocaleToMap(newTrMap, defaultLocale)
	mergeLocaleToMap(newTrMap, lang)
	mergeLocaleToMap(newTrMap, locale)
	if len(newTrMap) == 0 {
		return fmt.Errorf("Not found any translations, locale not set")
	}
	log.Tracef("Translations: %v", newTrMap)
	trMutex.Lock()
	defer trMutex.Unlock()
	trMap = newTrMap
	return nil
}

func mergeLocaleToMap(dst map[string]string, locale string) {
	if m, e := loadMapFromFile(locale); e != nil {
		log.Tracef("Locale %s not loaded: %s", locale, e)
	} else {
		for k, v := range m {
			dst[k] = v
		}
	}
}

func loadMapFromFile(locale string) (m map[string]string, err error) {
	fileName := locale + ".json"
	var buf []byte
	if buf, err = readFunc(fileName); err != nil {
		err = fmt.Errorf("Error read file %s: %s", fileName, err)
		return
	}
	if err = json.Unmarshal(buf, &m); err != nil {
		err = fmt.Errorf("Error decode json file %s: %s", fileName, err)
	}
	return
}
