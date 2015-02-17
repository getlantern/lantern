// package proxiedsites is a module used to manage the list of sites
// being proxied by Lantern
// when the list is modified using the Lantern UI, it propagates
// to the default YAML and PAC file configurations
package proxiedsites

import (
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/robertkrimen/otto"
	"github.com/robertkrimen/otto/parser"

	"gopkg.in/fatih/set.v0"
	"os"
	"path"
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
	log         = golog.LoggerFor("proxiedsites")
	ConfigDir   string
	PacFilePath string
	PacTmpl     = "src/github.com/getlantern/proxiedsites/templates/proxy_on.pac.template"
)

type Config struct {
	// Global list of white-listed domains
	Cloud []string `json:"-"`

	// User customizations
	Additions []string `json:"Additions, omitempty"`
	Deletions []string `json:"Deletions, omitempty"`
}

type ProxiedSites struct {
	cfg *Config

	// Corresponding global proxiedsites set
	cloudSet *set.Set
	addSet   set.Interface
	delSet   set.Interface

	entries []string
	pacFile *PacFile
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
	ConfigDir, err = util.GetUserHomeDir()
	if err != nil {
		log.Fatalf("Could not retrieve user home directory: %s", err)
		return
	}
	PacFilePath = path.Join(ConfigDir, PacFilename)
}

func New(cfg *Config) *ProxiedSites {
	// initialize our proxied site cloud set
	cloudSet := set.New()
	for i := range cfg.Cloud {
		cloudSet.Add(cfg.Cloud[i])
	}

	addSet := set.New()
	toAdd := append(cfg.Additions, cfg.Cloud...)
	for i := range toAdd {
		addSet.Add(toAdd[i])
	}

	delSet := set.New()
	for i := range cfg.Deletions {
		delSet.Add(cfg.Deletions[i])
	}

	entries := set.StringSlice(set.Difference(addSet, delSet))
	sort.Strings(entries)

	ps := &ProxiedSites{
		cfg:      cfg,
		cloudSet: cloudSet,
		entries:  entries,
		addSet:   addSet,
		delSet:   delSet,
	}

	go ps.updatePacFile()

	return ps
}

// Composes the add and delete deltas
// between a new proxiedsites and a previous proxiedsites instance
func (prev *ProxiedSites) Diff(cur *ProxiedSites) *Config {

	addSet := set.Difference(prev.addSet, cur.addSet)
	delSet := set.Difference(prev.delSet, cur.delSet)

	return &Config{
		Additions: set.StringSlice(addSet),
		Deletions: set.StringSlice(delSet),
	}
}

// Update modifies an existing ProxiedSites instance
// to include new addition and deletion deltas sent from
// the client
func (ps *ProxiedSites) Update(cfg *Config) {

	for i := range cfg.Additions {
		if !ps.cloudSet.Has(cfg.Additions[i]) {
			// if a new addition doesn't exist in our
			// cloud list already, add it to our addSet
			log.Debugf("Adding site %s", cfg.Additions[i])
			ps.addSet.Add(cfg.Additions[i])
			ps.cfg.Additions = append(ps.cfg.Additions,
				cfg.Additions[i])
		}
	}

	for i := range cfg.Deletions {
		ps.delSet.Add(cfg.Deletions[i])
		ps.cfg.Deletions = append(ps.cfg.Deletions, cfg.Deletions[i])
	}

	ps.entries = set.StringSlice(set.Difference(ps.addSet, ps.delSet))
	go ps.updatePacFile()
}

func (ps *ProxiedSites) RefreshEntries() []string {

	go ps.updatePacFile()

	return ps.entries
}

func GetPacFile() string {
	return PacFilePath
}

func (ps *ProxiedSites) Copy() *Config {
	return &Config{
		Additions: ps.cfg.Additions,
		Deletions: ps.cfg.Deletions,
		Cloud:     ps.cfg.Cloud,
	}
}

func (ps *ProxiedSites) GetConfig() *Config {
	return ps.cfg
}

func (ps *ProxiedSites) updatePacFile() (err error) {

	pacFile := &PacFile{}

	pacFile.file, err = os.Create(PacFilePath)
	defer pacFile.file.Close()
	if err != nil {
		log.Errorf("Could not create PAC file")
		return
	}
	// parse the PAC file template
	pacFile.template, err = template.ParseFiles(PacTmpl)
	if err != nil {
		log.Errorf("Could not open PAC file template: %s", err)
		return
	}

	log.Debugf("Updating PAC file; path is %s", PacFilePath)
	pacFile.l.Lock()
	defer pacFile.l.Unlock()

	data := make(map[string]interface{}, 0)
	data["Entries"] = ps.entries
	err = pacFile.template.Execute(pacFile.file, data)
	if err != nil {
		log.Errorf("Error generating updated PAC file: %s", err)
	}

	return err
}

func (ps *ProxiedSites) GetGlobalList() []string {
	return ps.cfg.Cloud
}

func (ps *ProxiedSites) GetEntries() []string {
	return ps.entries
}

func ParsePacFile() *ProxiedSites {
	ps := &ProxiedSites{}

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
			ps.entries = []string{}
			return ps
		}

		// need to remove escapes
		// and convert the otto value into a string array
		re := regexp.MustCompile("(\\\\.)")
		list := re.ReplaceAllString(value.String(), ".")
		ps.entries = strings.Split(list, ",")
		log.Debugf("List of proxied sites... %+v", ps.entries)
	}
	return ps
}
