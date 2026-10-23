//go:build windows

package apps

import (
	"crypto/rand"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/getlantern/radiance/common/processpath"
	"github.com/go-ole/go-ole"
	"github.com/go-ole/go-ole/oleutil"
	"golang.org/x/sys/windows/registry"
)

func TestWindowsStartMenuDiscovery(t *testing.T) {
	root := t.TempDir()
	path := filepath.Join(root, "Browser", "Firefox.exe")
	writeFile(t, path, "fixture", 0o600)
	startDir := filepath.Join(root, "Start Menu", "Programs")
	shortcut := filepath.Join(startDir, "Fixture Browser.lnk")
	checkBrowserError(t, os.MkdirAll(filepath.Dir(shortcut), 0o700))
	createBrowserShortcut(t, shortcut, path)

	apps := collectAppsFromStartMenuDirs([]string{startDir}, make(map[string]bool), nil)
	if findBrowserPath(apps, path) == nil {
		t.Fatal("Start Menu shortcut did not discover its executable")
	}
}

func TestWindowsAppPathsDiscovery(t *testing.T) {
	path := filepath.Join(t.TempDir(), "Browser", "Firefox.exe")
	writeFile(t, path, "fixture", 0o600)
	key := browserFixtureKey(t, `Software\Microsoft\Windows\CurrentVersion\App Paths\`+rand.Text()+`.exe`)
	checkBrowserError(t, key.SetStringValue("", `"`+path+`"`))

	apps := collectAppsFromAppPaths(make(map[string]bool), nil)
	if findBrowserPath(apps, path) == nil {
		t.Fatal("App Paths registration did not discover its executable")
	}
}

func TestWindowsRegisteredBrowserDiscovery(t *testing.T) {
	path := filepath.Join(t.TempDir(), "Browser", "Firefox.exe")
	writeFile(t, path, "fixture", 0o600)
	name := "LanternDiscoveryTest-" + rand.Text()
	classPath := `Software\Classes\` + name
	browserFixtureKey(t, classPath)
	browserFixtureKey(t, classPath+`\shell`)
	browserFixtureKey(t, classPath+`\shell\open`)
	command := browserFixtureKey(t, classPath+`\shell\open\command`)
	checkBrowserError(t, command.SetStringValue("", `"`+path+`" -osint -url "%1"`))
	capPath := classPath + `\Capabilities`
	browserFixtureKey(t, capPath)
	associations := browserFixtureKey(t, capPath+`\URLAssociations`)
	checkBrowserError(t, associations.SetStringValue("http", name))
	checkBrowserError(t, associations.SetStringValue("https", name))
	registrations, _, err := registry.CreateKey(registry.CURRENT_USER, `Software\RegisteredApplications`, registry.ALL_ACCESS|registry.WOW64_64KEY)
	checkBrowserError(t, err)
	t.Cleanup(func() { registrations.Close() })
	if _, _, err := registrations.GetStringValue(name); err != registry.ErrNotExist {
		t.Fatalf("fixture browser registration is not unused: %v", err)
	}
	checkBrowserError(t, registrations.SetStringValue(name, capPath))
	t.Cleanup(func() { checkBrowserError(t, registrations.DeleteValue(name)) })

	index := browserExeIndex{paths: make(map[string]bool), basenames: make(map[string]bool)}
	scanRegisteredApplicationBrowsers(&index)
	seen := make(map[string]bool)
	var emitted []*AppData
	apps := collectAppsFromRegisteredBrowsers(index, seen, func(apps ...*AppData) error {
		emitted = append(emitted, apps...)
		return nil
	})
	app := findBrowserPath(apps, path)
	if app == nil {
		t.Fatal("browser registration alone did not produce an app row")
	}
	if app.AppPath != processpath.Normalize(path) || app.BundleID != app.AppPath || !app.IsBrowser {
		t.Fatalf("incorrect registered browser metadata: %+v", app)
	}
	if findBrowserPath(emitted, path) != app {
		t.Fatal("registered browser was not emitted to the callback")
	}
	if repeated := collectAppsFromRegisteredBrowsers(index, seen, nil); len(repeated) != 0 {
		t.Fatalf("second scan duplicated %d registered paths", len(repeated))
	}

	seen = map[string]bool{strings.ToUpper(filepath.ToSlash(path)): true}
	apps = collectAppsFromRegisteredBrowsers(index, seen, nil)
	if findBrowserPath(apps, path) != nil {
		t.Fatal("duplicate of an executable already discovered by another source")
	}
}

func TestWindowsRegisteredBrowserDiscoveryKeepsDistinctExecutables(t *testing.T) {
	index := browserExeIndex{paths: make(map[string]bool), basenames: make(map[string]bool)}
	root := t.TempDir()
	for _, dir := range []string{"Stable", "Beta"} {
		path := filepath.Join(root, dir, "Firefox.exe")
		writeFile(t, path, "fixture", 0o600)
		index.addExe(path)
		index.addExe(strings.ToUpper(filepath.ToSlash(path)))
	}
	apps := collectAppsFromRegisteredBrowsers(index, make(map[string]bool), nil)
	if len(apps) != 2 || apps[0].AppPath == apps[1].AppPath {
		t.Fatalf("expected two distinct executables, got %+v", apps)
	}
}

func TestWindowsRegisteredBrowserDiscoveryRejectsInvalidPaths(t *testing.T) {
	index := browserExeIndex{paths: make(map[string]bool), basenames: make(map[string]bool)}
	root := t.TempDir()
	directory := filepath.Join(root, "Directory.exe")
	checkBrowserError(t, os.Mkdir(directory, 0o700))
	for _, path := range []string{
		filepath.Join(root, "Missing.exe"), directory,
		`firefox.exe`, `C:firefox.exe`, `\\server.invalid\share\firefox.exe`,
		`\\?\C:\Browser\firefox.exe`, `C:\Browser\file:firefox.exe`,
	} {
		index.paths[path] = true
	}
	if apps := collectAppsFromRegisteredBrowsers(index, make(map[string]bool), nil); len(apps) != 0 {
		t.Fatalf("invalid browser executables were discovered: %+v", apps)
	}
}

func TestWindowsInstalledBrowserDiscovery(t *testing.T) {
	path := os.Getenv("LANTERN_SMOKE_BROWSER_EXE")
	if path == "" {
		t.Skip("LANTERN_SMOKE_BROWSER_EXE is not set")
	}
	if !localBrowserExecutable(path) {
		t.Fatal("smoke browser must be a local absolute executable")
	}
	info, err := os.Stat(path)
	checkBrowserError(t, err)
	if !info.Mode().IsRegular() {
		t.Fatal("smoke browser is not a regular file")
	}
	var discovered []*AppData
	_, err = LoadInstalledAppsWithDirs(t.TempDir(), defaultAppDirs(), excludeDirs, func(apps ...*AppData) error {
		discovered = append(discovered, apps...)
		return nil
	})
	checkBrowserError(t, err)
	app := findBrowserPath(discovered, path)
	if app == nil {
		t.Fatal("installed browser was not discovered without manual selection")
	}
	if !app.IsBrowser {
		t.Fatal("installed browser did not appear in the browser category")
	}
}

func findBrowserPath(apps []*AppData, path string) *AppData {
	want := processpath.Normalize(path)
	for _, app := range apps {
		if processpath.Normalize(app.AppPath) == want {
			return app
		}
	}
	return nil
}

func browserFixtureKey(t *testing.T, path string) registry.Key {
	t.Helper()
	key, exists, err := registry.CreateKey(registry.CURRENT_USER, path, registry.ALL_ACCESS|registry.WOW64_64KEY)
	checkBrowserError(t, err)
	if exists {
		key.Close()
		t.Fatalf("fixture registry key already exists: %s", path)
	}
	t.Cleanup(func() {
		checkBrowserError(t, key.Close())
		checkBrowserError(t, registry.DeleteKey(registry.CURRENT_USER, path))
	})
	return key
}

func createBrowserShortcut(t *testing.T, path, target string) {
	t.Helper()
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	err := ole.CoInitializeEx(0, ole.COINIT_APARTMENTTHREADED)
	if err == nil {
		defer ole.CoUninitialize()
	} else {
		if !isRPCChangedMode(err) {
			t.Fatalf("initialize COM: %v", err)
		}
	}
	object, err := oleutil.CreateObject("WScript.Shell")
	checkBrowserError(t, err)
	defer object.Release()
	shell, err := object.QueryInterface(ole.IID_IDispatch)
	checkBrowserError(t, err)
	defer shell.Release()
	shortcut, err := oleutil.CallMethod(shell, "CreateShortcut", path)
	checkBrowserError(t, err)
	defer shortcut.Clear()
	dispatch := shortcut.ToIDispatch()
	_, err = oleutil.PutProperty(dispatch, "TargetPath", target)
	checkBrowserError(t, err)
	_, err = oleutil.CallMethod(dispatch, "Save")
	checkBrowserError(t, err)
}

func checkBrowserError(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}
