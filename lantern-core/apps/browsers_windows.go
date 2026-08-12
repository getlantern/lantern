//go:build windows

package apps

import (
	"log/slog"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"golang.org/x/sys/windows/registry"
)

// browserExeIndex holds the executables of the browsers registered on this
// machine, keyed by normalized full path and by lowercase basename.
type browserExeIndex struct {
	paths     map[string]bool
	basenames map[string]bool
}

// registryRoot pairs a registry hive with the access flags used to read it.
type registryRoot struct {
	root  registry.Key
	flags uint32
}

// browserRegistryRoots covers the hives/views installed browsers register
// under: both WOW64 views of HKLM (machine-wide installs) plus HKCU
// (per-user installs, and packaged browsers whose default-app registration
// lives under the current user).
var browserRegistryRoots = []registryRoot{
	{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_64KEY},
	{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_32KEY},
	{registry.CURRENT_USER, registry.READ | registry.WOW64_64KEY},
}

// loadBrowserIndexOnce builds the set of registered browser executables from
// the modern default-app registration, so any properly installed browser is
// detected without a hardcoded list:
//
//	Software\RegisteredApplications -> Capabilities\URLAssociations
//
// Each RegisteredApplications value points at a Capabilities key, and an app
// is a browser exactly when its URLAssociations declare an http/https handler.
// This covers both classic Win32 browsers (Chrome, Firefox, Edge, ...) and
// packaged/MSIX browsers (e.g. Arc), which register here rather than under the
// legacy Software\Clients\StartMenuInternet key.
//
// Portable browsers that skip registration entirely (e.g. Tor Browser) are
// not caught.
var loadBrowserIndexOnce = sync.OnceValue(func() browserExeIndex {
	idx := browserExeIndex{
		paths:     map[string]bool{},
		basenames: map[string]bool{},
	}

	scanRegisteredApplicationBrowsers(&idx)

	slog.Info("browser registry scan complete",
		"browsers", len(idx.paths),
		"basenames", sortedKeys(idx.basenames),
	)
	return idx
})

// addExe records a browser executable under both its full path and basename.
func (idx *browserExeIndex) addExe(exe string) {
	if exe == "" {
		return
	}
	idx.paths[normalizeKey(filepath.Clean(exe))] = true
	idx.basenames[strings.ToLower(filepath.Base(exe))] = true
}

// scanRegisteredApplicationBrowsers indexes browsers via the modern
// default-app registration: each Software\RegisteredApplications value points
// at a Capabilities key, and an app is a browser exactly when its
// Capabilities\URLAssociations declares an http/https handler. This catches
// classic Win32 browsers as well as packaged/MSIX browsers (Arc,
// Store-installed Chromium forks, ...).
func scanRegisteredApplicationBrowsers(idx *browserExeIndex) {
	const regAppsKey = `Software\RegisteredApplications`
	for _, r := range browserRegistryRoots {
		k, err := registry.OpenKey(r.root, regAppsKey, r.flags)
		if err != nil {
			continue
		}
		valueNames, _ := k.ReadValueNames(-1)
		capPaths := make([]string, 0, len(valueNames))
		for _, vn := range valueNames {
			capPath, _, err := k.GetStringValue(vn)
			if err == nil && strings.TrimSpace(capPath) != "" {
				capPaths = append(capPaths, strings.TrimSpace(capPath))
			}
		}
		k.Close()

		for _, capPath := range capPaths {
			addBrowserFromCapabilities(idx, r, capPath)
		}
	}
}

// addBrowserFromCapabilities inspects a Capabilities key and, when it
// declares an http/https URL handler, resolves that handler's executable into
// the index.
func addBrowserFromCapabilities(idx *browserExeIndex, r registryRoot, capPath string) {
	ua, err := registry.OpenKey(r.root, capPath+`\URLAssociations`, r.flags)
	if err != nil {
		return
	}
	defer ua.Close()

	for _, scheme := range []string{"http", "https"} {
		progID, _, err := ua.GetStringValue(scheme)
		if err != nil || strings.TrimSpace(progID) == "" {
			continue
		}
		idx.addExe(browserExeFromProgID(r, strings.TrimSpace(progID)))
	}
}

// browserExeFromProgID resolves a URL-handler ProgID to its executable via
// Software\Classes\<progID>\shell\open\command. It checks the ProgID's own
// hive first, then the opposite hive, since a per-user default may point at a
// machine-registered ProgID (or vice versa).
func browserExeFromProgID(r registryRoot, progID string) string {
	roots := []registry.Key{r.root}
	if r.root == registry.CURRENT_USER {
		roots = append(roots, registry.LOCAL_MACHINE)
	} else {
		roots = append(roots, registry.CURRENT_USER)
	}
	for _, root := range roots {
		ck, err := registry.OpenKey(
			root, `Software\Classes\`+progID+`\shell\open\command`, r.flags)
		if err != nil {
			continue
		}
		cmd, _, _ := ck.GetStringValue("")
		ck.Close()
		if exe := browserCommandExe(cmd); exe != "" {
			return exe
		}
	}
	return ""
}

// browserCommandExe extracts the executable path from a shell\open\command
// value (typically a quoted exe path, sometimes with arguments).
func browserCommandExe(cmd string) string {
	tokens := parseWindowsCommandTokens(cmd)
	if len(tokens) == 0 {
		return ""
	}
	exe := strings.Trim(strings.TrimSpace(tokens[0]), `"`)
	if exe == "" {
		return ""
	}
	exe = filepath.Clean(expandPercentEnv(exe))
	if !filepath.IsAbs(exe) || !strings.EqualFold(filepath.Ext(exe), ".exe") {
		return ""
	}
	return exe
}

// markBrowsers flags apps whose executable is a registered browser. Matches
// by full path first, then by basename — installs sometimes surface through
// a different discovery source (Start Menu vs App Paths) with an equivalent
// but not byte-identical path.
func markBrowsers(list []*AppData) {
	idx := loadBrowserIndexOnce()
	if len(idx.paths) == 0 && len(idx.basenames) == 0 {
		return
	}
	for _, app := range list {
		if app == nil {
			continue
		}
		// Recompute from the live registry index rather than trusting a flag
		// persisted by an older cache (e.g. a browser uninstalled since).
		app.IsBrowser = false
		p := strings.Trim(strings.TrimSpace(app.AppPath), `"`)
		if p == "" {
			continue
		}
		p = filepath.Clean(p)
		if idx.paths[normalizeKey(p)] || idx.basenames[strings.ToLower(filepath.Base(p))] {
			app.IsBrowser = true
		}
	}
}

func sortedKeys(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
