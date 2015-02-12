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
	PacTmpl     = "src/github.com/getlantern/whitelist/templates/proxy_on.pac.template"
	PacFilename = "proxy_on.pac"
)

var (
	log         = golog.LoggerFor("whitelist")
	ConfigDir   = util.DetermineConfigDir()
	pacFilePath = ConfigDir + "/" + PacFilename
)

type Config struct {
	/* Global list of white-listed domains */
	Cloud []string

	/* User customizations */
	Additions []string
	Deletions []string
}

type Whitelist struct {
	cfg *Config

	/* Corresponding global whitelist set */
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

func New(cfg *Config) *Whitelist {
	/* initialize our cloud set if we haven't already */
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
	return pacFilePath
}

func LoadDefaultList() []string {
	entries := []string{}
	domains, err := lists_original_txt()
	util.Check(err, log.Fatal, "Could not open original whitelist")

	scanner := bufio.NewScanner(bytes.NewReader(domains))
	for scanner.Scan() {
		s := scanner.Text()
		/* skip blank lines and comments */
		if s != "" && !strings.HasPrefix(s, "#") {
			entries = append(entries, s)
		}
	}
	return entries
}

func (wl *Whitelist) addOriginal() []string {
	wl.entries = LoadDefaultList()
	return wl.entries
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

func (wl *Whitelist) UpdateEntries(entries []string) []string {
	log.Debug("Updating whitelist entries...")

	toAdd := set.New()

	for i := range entries {
		toAdd.Add(entries[i])
	}

	toRemove := set.Difference(wl.cloudSet, toAdd)
	wl.cfg.Deletions = set.StringSlice(toRemove)
	log.Debugf("Whitelist domains deleted %+v", wl.cfg.Deletions)

	toAddSet := set.Difference(toAdd, wl.cloudSet)
	log.Debugf("New whitelist domains %+v", toAddSet)
	wl.entries = set.StringSlice(toAdd)
	go wl.updatePacFile()

	return wl.entries
}

func (wl *Whitelist) updatePacFile() (err error) {

	pacFile := &PacFile{}

	pacFile.file, err = os.Create(pacFilePath)
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

	log.Debugf("Updating PAC file; path is %s", pacFilePath)
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

func (wl *Whitelist) ParsePacFile() {
	log.Debugf("PAC file found %s; loading entries..", pacFilePath)
	/* pac file already present */
	program, err := parser.ParseFile(nil, pacFilePath, nil, 0)
	if err != nil {
		log.Errorf("Error parsing pac file +%v", err)
		/* we default to the original in this scenario */
		wl.addOriginal()
	} else {
		/* otto is a native JavaScript parser;
		we just quickly parse the proxy domains
		from the PAC file to
		cleanly send in a JSON response
		*/
		vm := otto.New()
		_, err := vm.Run(program)
		if err != nil {
			log.Errorf("Could not parse PAC file %+v", err)
			wl.addOriginal()
		} else {
			value, _ := vm.Get("proxyDomains")
			log.Debugf("PAC entries %+v", value.String())

			/* need to remove escapes
			* and convert the otto value into a string array
			 */
			re := regexp.MustCompile("(\\\\.)")
			list := re.ReplaceAllString(value.String(), ".")
			wl.entries = strings.Split(list, ",")
			log.Debugf("List of proxied sites... %+v", wl.entries)
		}
	}
}
