// package whitelist is a module used to manage the list of sites
// being proxied by Lantern
// when the list is modified using the Lantern UI, it propagates
// to the default YAML and PAC file configurations
package whitelist

import (
	"bufio"
	"bytes"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/robertkrimen/otto"
	"github.com/robertkrimen/otto/parser"

	"gopkg.in/fatih/set.v0"
	"os"
	"regexp"
	"sort"
	"strings"
	"sync"
	"text/template"
)

const (
	PacFilename = "proxy_on.pac"
)

var (
	log         = golog.LoggerFor("whitelist")
	ConfigDir   string
	PacFilePath string
	PacTmpl     = "src/github.com/getlantern/whitelist/templates/proxy_on.pac.template"
)

type Config struct {
	// Global list of white-listed domains
	Cloud []string

	// User customizations
	Additions []string
	Deletions []string
}

type Whitelist struct {
	cfg *Config

	// Corresponding global whitelist set
	cloudSet *set.Set
	entries  []string
	pacFile  *PacFile
}

type PacFile struct {
	fileName string
	l        sync.RWMutex
	template *template.Template
	file     *os.File
}

// Determine user home directory and PAC file path during initialization
func init() {
	var err error
	ConfigDir, err = util.DetermineConfigDir()
	if err != nil {
		log.Errorf("Could not open user home directory: %s", err)
		return
	}
	PacFilePath = ConfigDir + "/" + PacFilename
}

func New(cfg *Config) *Whitelist {
	// initialize our proxied site cloud set
	cloudSet := set.New()
	for i := range cfg.Cloud {
		cloudSet.Add(cfg.Cloud[i])
	}

	return &Whitelist{
		cfg:      cfg,
		cloudSet: cloudSet,
		entries:  []string{},
	}
}

func (wl *Whitelist) RefreshEntries() []string {
	entries := set.New()
	toAdd := append(wl.cfg.Additions, wl.cfg.Cloud...)
	for i := range toAdd {
		entries.Add(toAdd[i])
	}

	toRemove := set.New()
	for i := range wl.cfg.Deletions {
		toRemove.Add(wl.cfg.Deletions[i])
	}

	wl.entries = set.StringSlice(set.Difference(entries, toRemove))
	sort.Strings(wl.entries)

	go wl.updatePacFile()

	return wl.entries
}

func GetPacFile() string {
	return PacFilePath
}

// Loads the original.txt whitelist
func LoadDefaultList() []string {
	entries := []string{}
	domains, err := lists_original_txt()
	util.Check(err, log.Fatal, "Could not open original whitelist")

	scanner := bufio.NewScanner(bytes.NewReader(domains))
	for scanner.Scan() {
		s := scanner.Text()
		// skip blank lines and comments
		if s != "" && !strings.HasPrefix(s, "#") {
			entries = append(entries, s)
		}
	}
	return entries
}

func (wl *Whitelist) Copy() *Config {
	return &Config{
		Additions: wl.cfg.Additions,
		Deletions: wl.cfg.Deletions,
		Cloud:     wl.cfg.Cloud,
	}
}

func (wl *Whitelist) GetConfig() *Config {
	return wl.cfg
}

// This function calculaties the delta additions and deletions
// to the global whitelist; these changes are then propagated
// to the PAC file
func (wl *Whitelist) UpdateEntries(entries []string) []string {
	log.Debug("Updating whitelist entries...")

	toAdd := set.New()
	for i := range entries {
		toAdd.Add(entries[i])
	}

	// whitelist customizations
	toRemove := set.Difference(wl.cloudSet, toAdd)
	wl.cfg.Deletions = set.StringSlice(toRemove)

	// new entries are any new domains the user wishes
	// to proxy that weren't found on the global whitelist
	// already
	newEntries := set.Difference(toAdd, wl.cloudSet)
	wl.cfg.Additions = set.StringSlice(newEntries)
	wl.entries = set.StringSlice(toAdd)
	go wl.updatePacFile()

	return wl.entries
}

func (wl *Whitelist) updatePacFile() (err error) {

	pacFile := &PacFile{}

	pacFile.file, err = os.Create(PacFilePath)
	defer pacFile.file.Close()
	if err != nil {
		log.Errorf("Could not create PAC file")
		return
	}
	/* parse the PAC file template */
	pacFile.template, err = template.ParseFiles(PacTmpl)
	if err != nil {
		log.Errorf("Could not open PAC file template: %s", err)
		return
	}

	log.Debugf("Updating PAC file; path is %s", PacFilePath)
	pacFile.l.Lock()
	defer pacFile.l.Unlock()

	data := make(map[string]interface{}, 0)
	data["Entries"] = wl.entries
	err = pacFile.template.Execute(pacFile.file, data)
	if err != nil {
		log.Errorf("Error generating updated PAC file: %s", err)
	}

	return err
}

func (wl *Whitelist) GetEntries() []string {
	return wl.entries
}

func ParsePacFile() *Whitelist {
	wl := &Whitelist{}

	log.Debugf("PAC file found %s; loading entries..", PacFilePath)
	program, err := parser.ParseFile(nil, PacFilePath, nil, 0)
	// otto is a native JavaScript parser;
	// we just quickly parse the proxy domains
	// from the PAC file to
	// cleanly send in a JSON response
	vm := otto.New()
	_, err = vm.Run(program)
	if err != nil {
		log.Errorf("Could not parse PAC file %+v", err)
		return nil
	} else {
		value, _ := vm.Get("proxyDomains")
		log.Debugf("PAC entries %+v", value.String())
		if value.String() == "" {
			// no pac entries; return empty array
			wl.entries = []string{}
			return wl
		}

		// need to remove escapes
		// and convert the otto value into a string array
		re := regexp.MustCompile("(\\\\.)")
		list := re.ReplaceAllString(value.String(), ".")
		wl.entries = strings.Split(list, ",")
		log.Debugf("List of proxied sites... %+v", wl.entries)
	}
	return wl
}
