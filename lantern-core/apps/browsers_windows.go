//go:build windows

package apps

import (
	"log/slog"
	"path/filepath"
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

// loadBrowserIndexOnce reads Software\Clients\StartMenuInternet — the
// registry every installed browser joins to be eligible as the default
// browser (Chrome, Firefox, Edge, Brave, Opera, regional browsers, ...).
// Dynamic per device, so any properly installed browser is detected without
// a hardcoded list. Portable browsers that skip registration (e.g. Tor
// Browser) are not caught.
var loadBrowserIndexOnce = sync.OnceValue(func() browserExeIndex {
	idx := browserExeIndex{
		paths:     map[string]bool{},
		basenames: map[string]bool{},
	}

	const clientsKey = `Software\Clients\StartMenuInternet`
	type rootSpec struct {
		root  registry.Key
		flags uint32
	}
	roots := []rootSpec{
		{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_64KEY},
		{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_32KEY},
		// Per-user browser installs (e.g. user-level Chrome) register here.
		{registry.CURRENT_USER, registry.READ | registry.WOW64_64KEY},
	}

	for _, r := range roots {
		k, err := registry.OpenKey(r.root, clientsKey, r.flags)
		if err != nil {
			continue
		}
		names, _ := k.ReadSubKeyNames(-1)
		k.Close()

		for _, name := range names {
			ck, err := registry.OpenKey(
				r.root, clientsKey+`\`+name+`\shell\open\command`, r.flags)
			if err != nil {
				continue
			}
			cmd, _, _ := ck.GetStringValue("")
			ck.Close()

			exe := browserCommandExe(cmd)
			if exe == "" {
				continue
			}
			idx.paths[normalizeKey(filepath.Clean(exe))] = true
			idx.basenames[strings.ToLower(filepath.Base(exe))] = true
		}
	}

	slog.Info("browser registry scan complete",
		"browsers", len(idx.paths),
		"basenames", sortedKeys(idx.basenames),
	)
	return idx
})

// browserCommandExe extracts the executable path from a StartMenuInternet
// shell\open\command value (typically a quoted exe path, sometimes with
// arguments).
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
	return out
}
