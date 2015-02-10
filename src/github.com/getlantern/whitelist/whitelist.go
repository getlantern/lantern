package whitelist

import (
	"bufio"
	"bytes"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/robertkrimen/otto"
	"github.com/robertkrimen/otto/parser"
	"os"
	"regexp"
	"sort"
	"strings"
	"sync"
	"text/template"
)

const (
	WhiteListPath = "whitelist/whitelistgob"
	PacTmpl       = "whitelist/templates/proxy_on.pac.template"
	PacFilename   = "proxy_on.pac"
)

var (
	log         = golog.LoggerFor("whitelist")
	ConfigDir   = util.DetermineConfigDir()
	pacFilePath = ConfigDir + "/" + PacFilename
)

/* Thread-safe data structure representing a whitelist */
type Whitelist struct {
	entries map[string]bool
	m       sync.RWMutex
}

func New() *Whitelist {
	wl := &Whitelist{}
	wl.entries = map[string]bool{}

	log.Debugf("pac file path is %s", pacFilePath)

	if util.FileExists(pacFilePath) {
		/* pac file already present */
		wl.ParsePacFile()
	} else {
		/* Load original whitelist if no PAC file was found */
		wl.addOriginal()
		wl.genPacFile()
	}
	return wl
}

func NewWithEntries(entries []string) *Whitelist {
	wl := &Whitelist{}
	wl.entries = map[string]bool{}
	wl.add(entries)
	wl.genPacFile()
	return wl
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
	entries := LoadDefaultList()
	wl.add(entries)
	return entries
}

func (wl *Whitelist) add(entries []string) {
	wl.m.Lock()
	defer wl.m.Unlock()

	for _, entry := range entries {
		wl.entries[entry] = true
	}
}

func (wl *Whitelist) remove(entries []string) {
	wl.m.Lock()
	defer wl.m.Unlock()

	for _, entry := range entries {
		delete(wl.entries, entry)
	}
}

func (wl *Whitelist) Copy() []string {
	wl.m.RLock()
	defer wl.m.RUnlock()

	list := make([]string, 0, len(wl.entries))

	for entry, _ := range wl.entries {
		list = append(list, entry)
	}
	sort.Strings(list)
	return list
}

func (wl *Whitelist) Contains(site string) bool {
	wl.m.RLock()
	defer wl.m.RUnlock()

	return wl.entries[site]
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
			wl.add(strings.Split(list, ","))
			log.Debugf("List of proxied sites... %+v", wl.entries)
		}
	}

}

/* Generate a new PAC file if one doesn't exist already */
func (wl *Whitelist) genPacFile() {
	file, err := os.Create(pacFilePath)
	util.Check(err, log.Fatal, "Could not create PAC file")

	/* parse the PAC file template */
	t, err := template.ParseFiles(PacTmpl)
	util.Check(err, log.Fatal, "Could not parse template file")

	data := make(map[string]interface{}, 0)
	data["Entries"] = wl.Copy()

	err = t.Execute(file, data)
	util.Check(err, log.Fatal, "Error generating PAC file")
}
