//go:build windows

package apps

import (
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"

	"github.com/go-ole/go-ole"
	"github.com/go-ole/go-ole/oleutil"
	"golang.org/x/sys/windows/registry"
)

var excludeDirs = []string{
	os.Getenv("WINDIR"),
	// already handled via shortcuts scan
	// filepath.Join(os.Getenv("ProgramData"), "Microsoft", "Windows", "Start Menu"),
	// maybe skip common package caches
	// filepath.Join(os.Getenv("LOCALAPPDATA"), "Packages"),
}

func defaultAppDirs() []string {
	return []string{
		os.Getenv("LOCALAPPDATA"),
		os.Getenv("ProgramW6432"),
		os.Getenv("ProgramFiles"),
		os.Getenv("ProgramFiles(x86)"),
	}
}

var excludeNames = map[string]bool{
	"uninstall": true,
	"update":    true,
	"updater":   true,
	"install":   true,
	"setup":     true,
	"driver":    true,
}

var windowsHostExecutableNames = map[string]bool{
	"backgroundtaskhost.exe":      true,
	"conhost.exe":                 true,
	"dllhost.exe":                 true,
	"explorer.exe":                true,
	"runtimebroker.exe":           true,
	"searchhost.exe":              true,
	"shellexperiencehost.exe":     true,
	"sihost.exe":                  true,
	"startmenuexperiencehost.exe": true,
	"svchost.exe":                 true,
	"taskhostw.exe":               true,
	"textinputhost.exe":           true,
	"rundll32.exe":                true,
}

var windowsUtilityExecutableHints = map[string]bool{
	"actionsmcphost":            true,
	"ahost":                     true,
	"awk":                       true,
	"gitbash":                   true,
	"gitcmd":                    true,
	"gitgui":                    true,
	"gitk":                      true,
	"cmake":                     true,
	"cmakegui":                  true,
	"officelanguagepreferences": true,
	"pchealthcheck":             true,
	"microsoftvisualc":          true,
	"vcredist":                  true,
}

var windowsSystemDisplayNameHints = []string{
	"windowspowershell",
	"windowsterminal",
	"commandprompt",
	"taskmanager",
	"controlpanel",
	"snippingtool",
	"gethelp",
	"tips",
	"feedbackhub",
	"xbox",
}

var windowsExcludedStartMenuFolders = []string{
	"administrative tools",
	"startup",
	"system tools",
	"windows powershell",
	"windows terminal",
}

var windowsSystemRoots = computeWindowsSystemRoots()

const (
	appIsDir     = false
	appExtension = ".exe"
)

type uninstallEntryMetadata struct {
	systemComponentSet bool
	systemComponent    uint64
	noDisplaySet       bool
	noDisplay          uint64
	releaseType        string
}

type shortcutRecoveryHint struct {
	displayName          string
	normalizedCandidates []string
}

const packageCacheSearchDepth = 8

func normalizedWindowsDir() string {
	winDir := normalizeKey(strings.TrimSpace(os.Getenv("WINDIR")))
	if winDir == "" {
		winDir = normalizeKey(`C:\Windows`)
	}
	return filepath.Clean(winDir)
}

func computeWindowsSystemRoots() []string {
	winDir := normalizedWindowsDir()
	return []string{
		filepath.Clean(normalizeKey(filepath.Join(winDir, "System32"))),
		filepath.Clean(normalizeKey(filepath.Join(winDir, "SysWOW64"))),
		filepath.Clean(normalizeKey(filepath.Join(winDir, "WinSxS"))),
	}
}

// isLanternSelfApp filters Lantern itself out of the apps list — there's
// no point routing Lantern's own traffic through the split-tunnel UI.
// Matches by exe path under any Lantern install dir AND by basename for
// the known executables, so portable / non-default install paths still
// get filtered. See Freshdesk #173827.
func isLanternSelfApp(exePath, name string) bool {
	normalizedPath := strings.ToLower(filepath.Clean(strings.Trim(strings.TrimSpace(exePath), `"`)))
	if normalizedPath != "" {
		base := strings.TrimSuffix(filepath.Base(normalizedPath), filepath.Ext(normalizedPath))
		switch base {
		case "lantern", "lanternsvc", "lanternd":
			return true
		}
		if strings.Contains(normalizedPath, `\program files\lantern\`) ||
			strings.Contains(normalizedPath, `\program files (x86)\lantern\`) {
			return true
		}
	}
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "lantern", "lantern desktop", "lantern vpn":
		return true
	}
	// Match the registry's verbose DisplayName ("Lantern version X.Y.Z+N").
	if strings.HasPrefix(strings.ToLower(strings.TrimSpace(name)), "lantern version ") {
		return true
	}
	return false
}

func isWindowsSystemApp(exePath, name string) bool {
	normalizedPath := normalizeKey(strings.Trim(strings.TrimSpace(exePath), `"`))
	if normalizedPath != "" {
		normalizedPath = filepath.Clean(normalizedPath)
	}

	for _, root := range windowsSystemRoots {
		if root == "" || normalizedPath == "" {
			continue
		}
		if normalizedPath == root || strings.HasPrefix(normalizedPath, root+`\`) {
			return true
		}
	}

	if normalizedPath != "" {
		if windowsHostExecutableNames[normalizeKey(filepath.Base(normalizedPath))] {
			return true
		}
	}

	if normalizedPath == "" {
		normalizedName := normalizeKey(strings.TrimSpace(name))
		if normalizedName != "" {
			normalizedName = strings.TrimSuffix(normalizedName, ".exe")
			if windowsHostExecutableNames[normalizedName+".exe"] {
				return true
			}
		}
	}

	return false
}

func isWindowsUtilityApp(exePath, name string) bool {
	candidates := []string{
		filepath.Base(strings.Trim(strings.TrimSpace(exePath), `"`)),
		strings.TrimSpace(name),
	}

	for _, candidate := range candidates {
		normalized := normalizeExecutableHint(candidate)
		if normalized == "" {
			continue
		}
		if windowsUtilityExecutableHints[normalized] {
			return true
		}
		for hint := range windowsUtilityExecutableHints {
			if len(hint) < 4 {
				continue
			}
			if hint != "" && strings.Contains(normalized, hint) {
				return true
			}
		}
	}

	return false
}

func isLikelySystemDisplayName(name string) bool {
	normalized := normalizeExecutableHint(name)
	if normalized == "" {
		return false
	}
	for _, hint := range windowsSystemDisplayNameHints {
		if strings.Contains(normalized, hint) {
			return true
		}
	}
	return false
}

func isExcludedStartMenuShortcutPath(shortcutPath string) bool {
	if strings.TrimSpace(shortcutPath) == "" {
		return false
	}
	segments := strings.Split(
		normalizeKey(filepath.Clean(shortcutPath)),
		`\`,
	)
	for _, segment := range segments {
		segment = strings.TrimSpace(segment)
		if segment == "" {
			continue
		}
		for _, excluded := range windowsExcludedStartMenuFolders {
			if segment == excluded {
				return true
			}
		}
	}
	return false
}

// loadInstalledAppsPlatform returns a list of installed applications for Windows
// Discovery order:
//  1. Start Menu shortcuts: the best “user-facing apps” list
//  2. Uninstall registry entries: catches apps that don’t have Start Menu shortcuts
//  3. Fallback directory scan
func loadInstalledAppsPlatform(appDirs []string, seen map[string]bool, excludeDirs []string, cb Callback) []*AppData {
	var out []*AppData

	startMenuApps := collectAppsFromStartMenuShortcuts(seen, cb)
	out = append(out, startMenuApps...)

	registryApps := collectAppsFromUninstallRegistry(seen, cb)
	out = append(out, registryApps...)

	// App Paths: HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths.
	// Apps register here so they're invocable via Win+R; (Default) is the
	// full exe path. Catches browsers, IDEs, Office. Cheap.
	appPathsApps := collectAppsFromAppPaths(seen, cb)
	out = append(out, appPathsApps...)

	// Run keys: HKLM/HKCU\...\CurrentVersion\Run. Squirrel/Electron apps
	// (Slack, Discord, Claude, GitHub Desktop) register an auto-start
	// command line here pointing at Update.exe --processStart "<App>.exe".
	// We reuse the same processStart parsing as Start Menu shortcuts.
	runApps := collectAppsFromRunRegistry(seen, cb)
	out = append(out, runApps...)

	// Squirrel pattern: walk %LOCALAPPDATA% one level deep looking for
	// <AppName>\Update.exe. Backstop for Squirrel apps that don't show up
	// in Start Menu or Run (e.g. user disabled auto-start).
	squirrelApps := collectAppsFromSquirrelLocalAppData(seen, cb)
	out = append(out, squirrelApps...)

	// Always log a summary at Info so a single log read tells us how many
	// apps each source produced. Helps diagnose tickets like
	// engineering#3335 / Freshdesk #173774 without a second round-trip.
	slog.Info(
		"windows app scan summary",
		"startMenuCount", len(startMenuApps),
		"registryCount", len(registryApps),
		"appPathsCount", len(appPathsApps),
		"runCount", len(runApps),
		"squirrelCount", len(squirrelApps),
		"total", len(out),
	)

	// Fallback: recursive app scan
	if len(out) == 0 {
		if !windowsDirectoryFallbackEnabled() {
			slog.Warn(
				"no windows apps from start menu/registry and directory fallback disabled",
				"startMenuCount",
				len(startMenuApps),
				"registryCount",
				len(registryApps),
			)
			return out
		}
		slog.Warn(
			"no windows apps from start menu/registry; falling back to directory scan",
			"startMenuCount",
			len(startMenuApps),
			"registryCount",
			len(registryApps),
		)
		out = append(out, scanAppDirs(appDirs, seen, excludeDirs, cb)...)
	}

	return out
}

func windowsDirectoryFallbackEnabled() bool {
	value := strings.TrimSpace(os.Getenv("LANTERN_WINDOWS_APP_DIR_FALLBACK"))
	return strings.EqualFold(value, "1") ||
		strings.EqualFold(value, "true") ||
		strings.EqualFold(value, "yes")
}

func windowsStartMenuDirs() []string {
	appdata := os.Getenv("APPDATA")
	programData := os.Getenv("ProgramData")

	return []string{
		filepath.Join(appdata, "Microsoft", "Windows", "Start Menu", "Programs"),
		filepath.Join(programData, "Microsoft", "Windows", "Start Menu", "Programs"),
	}
}

// collectAppsFromStartMenuShortcuts enumerates apps by walking Start Menu shortcut files (*.lnk)
func collectAppsFromStartMenuShortcuts(seen map[string]bool, cb Callback) []*AppData {
	startDirs := windowsStartMenuDirs()
	var out []*AppData
	recoveryHints := make(map[string]shortcutRecoveryHint)

	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	inited := false
	if err := ole.CoInitializeEx(0, ole.COINIT_APARTMENTTHREADED); err != nil {
		// If COM is already initialized in a different mode, we can often still proceed
		if !isRPCChangedMode(err) {
			// Warn (not Debug) so an empty apps list surfaces the root cause.
			slog.Warn("CoInitializeEx failed, skipping Start Menu app scan", "err", err)
			return out
		}
	} else {
		inited = true
	}
	if inited {
		defer ole.CoUninitialize()
	}

	wshObj, err := oleutil.CreateObject("WScript.Shell")
	if err != nil {
		slog.Warn("WScript.Shell not available, skipping Start Menu app scan", "err", err)
		return out
	}
	defer wshObj.Release()

	wsh, err := wshObj.QueryInterface(ole.IID_IDispatch)
	if err != nil {
		slog.Warn("WScript.Shell QueryInterface failed, skipping Start Menu app scan", "err", err)
		return out
	}
	defer wsh.Release()

	var totalShortcuts, droppedUnresolved, droppedSystem, droppedSelf, droppedUtilityOrExcluded, droppedDuplicate int
	// Per-shortcut samples for diagnosing missing apps (e.g. a Squirrel
	// shortcut that gets caught by isWindowsUtilityApp or an excluded path).
	// 50-entry cap on unresolved is comfortably bigger than typical scans
	// (~37 in the wild) so we don't truncate; the filtered buckets are
	// usually small enough that 20 is plenty.
	const maxUnresolvedSamples = 50
	const maxFilteredSamples = 20
	var (
		droppedUnresolvedSamples       []string
		droppedUtilityOrExcludedSample []string
	)
	rootsScanned := make([]string, 0, len(startDirs))
	rootsMissing := make([]string, 0, len(startDirs))

	for _, root := range startDirs {
		root = strings.TrimSpace(root)
		if root == "" {
			continue
		}
		if st, err := os.Stat(root); err != nil || !st.IsDir() {
			rootsMissing = append(rootsMissing, root)
			continue
		}
		rootsScanned = append(rootsScanned, root)

		_ = filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
			if err != nil || d == nil {
				return nil
			}
			if d.IsDir() {
				return nil
			}
			if !strings.HasSuffix(strings.ToLower(d.Name()), ".lnk") {
				return nil
			}
			totalShortcuts++

			targetExe, iconFile, iconIndex, shortcutArgs, shortcutWorkDir := resolveLnkViaWScript(wsh, p)
			name := shortcutDisplayName(d.Name(), targetExe)
			recoveryHint := shortcutRecoveryHintFromShortcut(name, shortcutArgs)
			targetExe = resolveShortcutExecutable(
				targetExe,
				iconFile,
				p,
				name,
				shortcutArgs,
				shortcutWorkDir,
			)
			if targetExe == "" {
				droppedUnresolved++
				if len(droppedUnresolvedSamples) < maxUnresolvedSamples {
					droppedUnresolvedSamples = append(droppedUnresolvedSamples,
						fmt.Sprintf("%s (name=%q)", p, name))
				}
				if recoveryHint.isValid() {
					recoveryHints[recoveryHint.key()] = recoveryHint
				}
				return nil
			}
			if isWindowsSystemApp(targetExe, name) {
				droppedSystem++
				if recoveryHint.isValid() {
					recoveryHints[recoveryHint.key()] = recoveryHint
				}
				return nil
			}
			if isLanternSelfApp(targetExe, name) {
				droppedSelf++
				return nil
			}
			if isExcludedStartMenuShortcutPath(p) || isWindowsUtilityApp(targetExe, name) {
				droppedUtilityOrExcluded++
				if len(droppedUtilityOrExcludedSample) < maxFilteredSamples {
					reason := "utility"
					if isExcludedStartMenuShortcutPath(p) {
						reason = "excluded-path"
					}
					droppedUtilityOrExcludedSample = append(droppedUtilityOrExcludedSample,
						fmt.Sprintf("%s → %s (name=%q reason=%s)", p, targetExe, name, reason))
				}
				return nil
			}
			keyPath := normalizeKey(targetExe)
			if seen[keyPath] {
				droppedDuplicate++
				return nil
			}

			iconLocation := strings.TrimSpace(targetExe)
			if strings.TrimSpace(iconFile) != "" {
				iconLocation = strings.TrimSpace(fmt.Sprintf("%s,%d", iconFile, iconIndex))
			}

			app := &AppData{
				Name:     name,
				BundleID: targetExe,
				AppPath:  targetExe,
				IconPath: iconLocation,
			}

			if cb != nil {
				cb(app)
			}
			out = append(out, app)
			seen[keyPath] = true
			return nil
		})
	}

	var recovered int
	if len(recoveryHints) > 0 {
		recoveredApps := collectAppsFromPackageCacheHints(recoveryHints, seen, cb)
		out = append(out, recoveredApps...)
		recovered = len(recoveredApps)
	}

	slog.Info(
		"start menu scan complete",
		"appdata", os.Getenv("APPDATA"),
		"programData", os.Getenv("ProgramData"),
		"rootsScanned", rootsScanned,
		"rootsMissing", rootsMissing,
		"shortcuts", totalShortcuts,
		"kept", len(out),
		"droppedUnresolved", droppedUnresolved,
		"droppedSystem", droppedSystem,
		"droppedSelf", droppedSelf,
		"droppedUtilityOrExcluded", droppedUtilityOrExcluded,
		"droppedDuplicate", droppedDuplicate,
		"packageCacheHintsRecovered", recovered,
		"sampleKept", sampleAppNames(out, 20),
		"sampleDroppedUnresolved", droppedUnresolvedSamples,
		"sampleDroppedUtilityOrExcluded", droppedUtilityOrExcludedSample,
	)

	return out
}

// sampleAppNames returns up to n "name (executable)" strings, for use as a
// slog slice attribute on scan summaries. The executable path is redacted to
// its basename — these samples land in scan-summary log lines that get
// bundled into "Report Issue" tickets, so we don't want full paths
// (typically C:\Users\<username>\...) in there as PII. Basename keeps enough
// signal for diagnostics ("did Slack get included? did chrome.exe get
// included?") without leaking user filesystem layout.
func sampleAppNames(apps []*AppData, n int) []string {
	if n > len(apps) {
		n = len(apps)
	}
	out := make([]string, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, fmt.Sprintf("%s (%s)", apps[i].Name, filepath.Base(apps[i].AppPath)))
	}
	return out
}

// isRPCChangedMode reports whether err is RPC_E_CHANGED_MODE
func isRPCChangedMode(err error) bool {
	if err == nil {
		return false
	}
	oe, ok := err.(*ole.OleError)
	if !ok || oe == nil {
		return false
	}

	// ole.OleError.Code() returns the HRESULT
	const rpcEChangedMode = 0x80010106
	return uint32(oe.Code()) == rpcEChangedMode
}

func resolveLnkViaWScript(wsh *ole.IDispatch, lnkPath string) (targetExe string, iconFile string, iconIndex int, args string, workingDir string) {
	v, err := oleutil.CallMethod(wsh, "CreateShortcut", lnkPath)
	if err != nil {
		return "", "", 0, "", ""
	}

	sc := v.ToIDispatch()
	defer sc.Release()

	iconLoc := ""
	if tp, err := oleutil.GetProperty(sc, "TargetPath"); err == nil {
		defer tp.Clear()
		targetExe = strings.TrimSpace(tp.ToString())
	}
	if il, err := oleutil.GetProperty(sc, "IconLocation"); err == nil {
		defer il.Clear()
		iconLoc = strings.TrimSpace(il.ToString())
	}
	if argp, err := oleutil.GetProperty(sc, "Arguments"); err == nil {
		defer argp.Clear()
		args = strings.TrimSpace(argp.ToString())
	}
	if wdp, err := oleutil.GetProperty(sc, "WorkingDirectory"); err == nil {
		defer wdp.Clear()
		workingDir = strings.TrimSpace(wdp.ToString())
	}

	iconFile, iconIndex = parseIconLocation(iconLoc)
	return targetExe, iconFile, iconIndex, args, workingDir
}

// Reads “installed apps” entries from:
// - HKLM/HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall
// - both 64-bit + 32-bit views when possible
func collectAppsFromUninstallRegistry(seen map[string]bool, cb Callback) []*AppData {
	var out []*AppData

	type root struct {
		key   registry.Key
		path  string
		flags uint32
	}

	const uninstallPath = `Software\Microsoft\Windows\CurrentVersion\Uninstall`

	roots := []root{
		{registry.LOCAL_MACHINE, uninstallPath, registry.READ | registry.WOW64_64KEY},
		{registry.LOCAL_MACHINE, uninstallPath, registry.READ | registry.WOW64_32KEY},
		{registry.CURRENT_USER, uninstallPath, registry.READ | registry.WOW64_64KEY},
		{registry.CURRENT_USER, uninstallPath, registry.READ | registry.WOW64_32KEY},
	}

	var totalEntries, droppedNonUserFacing, droppedNoDisplayName, droppedNoExe,
		droppedSystem, droppedSelf, droppedUtility, droppedExcluded, droppedDuplicate int
	// Samples for diagnosing missing apps. NoExe = had a name but couldn't
	// resolve an exe; NoDisplayName = the much bigger bucket where the
	// registry entry skipped the DisplayName field entirely (Squirrel apps
	// like Claude often show up here under their subkey names).
	const maxRegistryDroppedSamples = 20
	var (
		droppedNoExeSamples         []string
		droppedNoDisplayNameSamples []string
	)

	for _, r := range roots {
		k, err := registry.OpenKey(r.key, r.path, r.flags)
		if err != nil {
			continue
		}

		names, _ := k.ReadSubKeyNames(-1)
		k.Close()

		for _, sub := range names {
			totalEntries++
			sk, err := registry.OpenKey(r.key, r.path+`\`+sub, r.flags)
			if err != nil {
				continue
			}

			metadata := readUninstallEntryMetadata(sk)
			if isNonUserFacingUninstallEntry(metadata) {
				droppedNonUserFacing++
				sk.Close()
				continue
			}

			displayName, _, _ := sk.GetStringValue("DisplayName")
			displayIcon, _, _ := sk.GetStringValue("DisplayIcon")
			installLoc, _, _ := sk.GetStringValue("InstallLocation")
			sk.Close()

			displayName = strings.TrimSpace(displayName)
			if displayName == "" {
				// No name usually indicates an app is "not user-facing", so skip
				droppedNoDisplayName++
				if len(droppedNoDisplayNameSamples) < maxRegistryDroppedSamples {
					droppedNoDisplayNameSamples = append(droppedNoDisplayNameSamples,
						fmt.Sprintf("%s (icon=%q installLoc=%q)", sub, displayIcon, installLoc))
				}
				continue
			}

			exePath := pickExePath(displayIcon, installLoc)
			if exePath == "" || !strings.HasSuffix(strings.ToLower(exePath), ".exe") {
				droppedNoExe++
				if len(droppedNoExeSamples) < maxRegistryDroppedSamples {
					droppedNoExeSamples = append(droppedNoExeSamples,
						fmt.Sprintf("%s (icon=%q installLoc=%q)", displayName, displayIcon, installLoc))
				}
				continue
			}
			exePath = resolveWrappedExecutable(exePath, displayName)
			if exePath == "" {
				droppedNoExe++
				if len(droppedNoExeSamples) < maxRegistryDroppedSamples {
					droppedNoExeSamples = append(droppedNoExeSamples,
						fmt.Sprintf("%s (wrapped resolve failed for %q)", displayName, displayIcon))
				}
				continue
			}
			if isWindowsSystemApp(exePath, displayName) {
				droppedSystem++
				continue
			}
			if isLanternSelfApp(exePath, displayName) {
				droppedSelf++
				continue
			}
			if isWindowsUtilityApp(exePath, displayName) {
				droppedUtility++
				continue
			}

			// Don't show uninstallers/updaters
			if isExcludedName(filepathBaseNoExt(exePath)) {
				droppedExcluded++
				continue
			}

			appID := exePath
			keyID := normalizeKey(appID)
			keyPath := normalizeKey(exePath)
			if seen[keyID] || seen[keyPath] {
				droppedDuplicate++
				continue
			}

			app := &AppData{
				Name:     displayName,
				BundleID: appID,
				AppPath:  exePath,
				IconPath: strings.TrimSpace(displayIcon),
			}

			if cb != nil {
				cb(app)
			}
			out = append(out, app)

			seen[keyID] = true
			seen[keyPath] = true
		}
	}

	slog.Info(
		"uninstall registry scan complete",
		"scanned", totalEntries,
		"kept", len(out),
		"droppedNonUserFacing", droppedNonUserFacing,
		"droppedNoDisplayName", droppedNoDisplayName,
		"droppedNoExe", droppedNoExe,
		"droppedSystem", droppedSystem,
		"droppedSelf", droppedSelf,
		"droppedUtility", droppedUtility,
		"droppedExcluded", droppedExcluded,
		"droppedDuplicate", droppedDuplicate,
		"sampleKept", sampleAppNames(out, 20),
		"sampleDroppedNoExe", droppedNoExeSamples,
		"sampleDroppedNoDisplayName", droppedNoDisplayNameSamples,
	)

	return out
}

// collectAppsFromAppPaths reads HKLM\Software\Microsoft\Windows\CurrentVersion\
// App Paths. Each subkey's name is the executable filename (e.g. "chrome.exe")
// and its (Default) value is the full path. Apps register here when they
// want to be runnable via Win+R / shellexecute. Catches browsers, IDEs,
// Office, and most third-party apps that don't go through Squirrel.
func collectAppsFromAppPaths(seen map[string]bool, cb Callback) []*AppData {
	const appPathsKey = `Software\Microsoft\Windows\CurrentVersion\App Paths`
	type rootSpec struct {
		root  registry.Key
		flags uint32
	}
	roots := []rootSpec{
		{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_64KEY},
		{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_32KEY},
		{registry.CURRENT_USER, registry.READ | registry.WOW64_64KEY},
	}

	var out []*AppData
	var scanned, kept, droppedNoPath, droppedSystem, droppedSelf, droppedUtility, droppedNoise, droppedDuplicate int

	for _, r := range roots {
		k, err := registry.OpenKey(r.root, appPathsKey, r.flags)
		if err != nil {
			continue
		}
		names, _ := k.ReadSubKeyNames(-1)
		k.Close()

		for _, name := range names {
			scanned++
			sk, err := registry.OpenKey(r.root, appPathsKey+`\`+name, r.flags)
			if err != nil {
				continue
			}
			exePath, _, _ := sk.GetStringValue("")
			sk.Close()

			exePath = strings.Trim(strings.TrimSpace(exePath), `"`)
			if exePath == "" {
				droppedNoPath++
				continue
			}
			exePath = filepath.Clean(expandPercentEnv(exePath))
			if !filepath.IsAbs(exePath) || !fileExists(exePath) ||
				!strings.EqualFold(filepath.Ext(exePath), ".exe") {
				droppedNoPath++
				continue
			}

			displayName := strings.TrimSuffix(name, filepath.Ext(name))
			if isWindowsSystemApp(exePath, displayName) {
				droppedSystem++
				continue
			}
			if isLanternSelfApp(exePath, displayName) {
				droppedSelf++
				continue
			}
			if isWindowsUtilityApp(exePath, displayName) {
				droppedUtility++
				continue
			}
			if isLikelySystemDisplayName(displayName) {
				droppedSystem++
				continue
			}
			if isAppPathsNoise(exePath, displayName) {
				droppedNoise++
				continue
			}

			key := normalizeKey(exePath)
			if seen[key] {
				droppedDuplicate++
				continue
			}
			seen[key] = true

			app := &AppData{
				Name:     displayName,
				BundleID: exePath,
				AppPath:  exePath,
			}
			if cb != nil {
				cb(app)
			}
			out = append(out, app)
			kept++
		}
	}

	slog.Info(
		"app paths scan complete",
		"scanned", scanned,
		"kept", kept,
		"droppedNoPath", droppedNoPath,
		"droppedSystem", droppedSystem,
		"droppedSelf", droppedSelf,
		"droppedUtility", droppedUtility,
		"droppedNoise", droppedNoise,
		"droppedDuplicate", droppedDuplicate,
		"sampleKept", sampleAppNames(out, 20),
	)
	return out
}

// isAppPathsNoise filters App Paths-specific noise that escapes the
// generic system / utility filters. App Paths is heavily polluted by
// Microsoft-bundled tooling (IE relics, Office helpers, vestigial Mail
// + tablet apps) and by UWP packages that register helper exes alongside
// their main app. We keep those filters local to this scanner so they
// can be aggressive without affecting Start Menu / Uninstall scans.
//
// Rules:
//   - Drop entries under known system / vestigial paths.
//   - Drop entries under \Microsoft Office\ unless the basename is a
//     primary Office product exe (those normally arrive via Start Menu;
//     anything else here is a background tool).
//   - Drop helper-named basenames (containing "update", "helper",
//     "browsersupport", etc.) anywhere in the path.
//
// Constant data (paths, hints, suffixes) is hoisted to package scope so
// the per-entry hot path stays allocation-free — this runs once per
// HKLM\...\App Paths entry, which is hundreds-to-thousands of calls per
// scan.
func isAppPathsNoise(exePath, displayName string) bool {
	norm := strings.ToLower(filepath.Clean(strings.Trim(strings.TrimSpace(exePath), `"`)))
	if norm == "" {
		return false
	}

	for _, p := range appPathsNoiseSystemPaths {
		if strings.Contains(norm, p) {
			return true
		}
	}

	// Office Root: drop everything except the primary product exes
	// (those also come via Start Menu, so duplicates hit dedup).
	if strings.Contains(norm, `\microsoft office\`) {
		if !appPathsNoisePrimaryOfficeExes[strings.ToLower(filepath.Base(norm))] {
			return true
		}
	}

	// Helper-named basenames. Substring match (case-insensitive, after
	// stripping non-alnum) so "ms-teamsupdate" → "msteamsupdate" matches
	// "update", and "1Password-BrowserSupport" → "1passwordbrowsersupport"
	// matches "browsersupport".
	base := normalizeExecutableHint(filepath.Base(norm))
	for _, h := range appPathsNoiseHelperHints {
		if strings.Contains(base, h) {
			return true
		}
	}
	// Suffix-only check for words too generic to substring-match safely.
	for _, suffix := range appPathsNoiseGenericSuffixes {
		if strings.HasSuffix(base, suffix) && base != suffix {
			return true
		}
	}

	return false
}

// Hoisted constant data for isAppPathsNoise. See the function comment for
// what each list captures.
var (
	appPathsNoiseSystemPaths = []string{
		`\program files\internet explorer\`,
		`\program files (x86)\internet explorer\`,
		`\program files\windows mail\`,
		`\program files (x86)\windows mail\`,
		`\program files\windows nt\`,
		`\program files (x86)\windows nt\`,
		`\program files\windows defender\`,
		`\program files (x86)\windows defender\`,
		`\common files\microsoft shared\`,
		`\common files\microsoft.net\`,
		// UWP package plumbing: winget + WindowsPackageManagerServer
		// register App Paths entries but aren't user-facing GUI apps.
		`\windowsapps\microsoft.desktopappinstaller_`,
		// .NET helper assemblies under UWP packages (e.g. Power Automate
		// Desktop registers PAD.BrowserNativeMessageHost, PAD.ChildSession.
		// Service.Host under \dotnet\). The user-facing exe of a UWP
		// package always sits at the package root, never under \dotnet\.
		`\dotnet\`,
	}

	appPathsNoisePrimaryOfficeExes = map[string]bool{
		"winword.exe":  true,
		"excel.exe":    true,
		"powerpnt.exe": true,
		"outlook.exe":  true,
		"msaccess.exe": true,
		"mspub.exe":    true,
		"onenote.exe":  true,
		"lync.exe":     true,
		"groove.exe":   true,
		"visio.exe":    true,
		"winproj.exe":  true,
	}

	appPathsNoiseHelperHints = []string{
		"browsersupport",
		"lastpassexporter",
		"sshsign",
		"sshagent",
		"updater",
		"helper",
		"diagnostic",
		"diagcmd",
	}

	appPathsNoiseGenericSuffixes = []string{
		"update", "service", "agent", "sync", "broker",
	}
)

// collectAppsFromRunRegistry reads HKLM\...\Run and HKCU\...\Run. Apps that
// register for auto-start (the dominant case is Squirrel apps —
// "com.squirrel.<App>.<App>" pointing at Update.exe --processStart) write
// a command line here. We parse the command line the same way we parse
// Start Menu .lnk targets, including the --processStart fallback.
func collectAppsFromRunRegistry(seen map[string]bool, cb Callback) []*AppData {
	const runKey = `Software\Microsoft\Windows\CurrentVersion\Run`
	type rootSpec struct {
		root  registry.Key
		flags uint32
	}
	roots := []rootSpec{
		{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_64KEY},
		{registry.LOCAL_MACHINE, registry.READ | registry.WOW64_32KEY},
		{registry.CURRENT_USER, registry.READ | registry.WOW64_64KEY},
	}

	var out []*AppData
	var scanned, kept, droppedNoExe, droppedSystem, droppedSelf, droppedUtility, droppedExcluded, droppedDuplicate int

	for _, r := range roots {
		k, err := registry.OpenKey(r.root, runKey, r.flags)
		if err != nil {
			continue
		}
		valueNames, _ := k.ReadValueNames(-1)
		for _, valueName := range valueNames {
			scanned++
			cmdLine, _, err := k.GetStringValue(valueName)
			if err != nil {
				continue
			}
			exePath, displayName := parseRunEntry(valueName, cmdLine)
			if exePath == "" {
				droppedNoExe++
				continue
			}

			if isWindowsSystemApp(exePath, displayName) {
				droppedSystem++
				continue
			}
			if isLanternSelfApp(exePath, displayName) {
				droppedSelf++
				continue
			}
			if isWindowsUtilityApp(exePath, displayName) {
				droppedUtility++
				continue
			}
			if isExcludedName(filepathBaseNoExt(exePath)) {
				droppedExcluded++
				continue
			}

			key := normalizeKey(exePath)
			if seen[key] {
				droppedDuplicate++
				continue
			}
			seen[key] = true

			app := &AppData{
				Name:     displayName,
				BundleID: exePath,
				AppPath:  exePath,
			}
			if cb != nil {
				cb(app)
			}
			out = append(out, app)
			kept++
		}
		k.Close()
	}

	slog.Info(
		"run registry scan complete",
		"scanned", scanned,
		"kept", kept,
		"droppedNoExe", droppedNoExe,
		"droppedSystem", droppedSystem,
		"droppedSelf", droppedSelf,
		"droppedUtility", droppedUtility,
		"droppedExcluded", droppedExcluded,
		"droppedDuplicate", droppedDuplicate,
		"sampleKept", sampleAppNames(out, 20),
	)
	return out
}

// parseRunEntry extracts an absolute exe path from a Run-key command line.
// Squirrel/Electron form: "<dir>\Update.exe" --processStart "<App>.exe"
// — when the head exe is excluded (Update / Updater / etc.) we use the
// existing --processStart hint to find the real app exe. Returns ("", "")
// if we can't resolve a real exe.
func parseRunEntry(valueName, cmdLine string) (string, string) {
	cmdLine = strings.TrimSpace(cmdLine)
	if cmdLine == "" {
		return "", ""
	}
	tokens := parseWindowsCommandTokens(cmdLine)
	if len(tokens) == 0 {
		return "", ""
	}
	headExe := strings.Trim(strings.TrimSpace(tokens[0]), `"`)
	if headExe == "" {
		return "", ""
	}
	headExe = filepath.Clean(expandPercentEnv(headExe))
	if !filepath.IsAbs(headExe) || !fileExists(headExe) {
		return "", ""
	}
	args := ""
	if len(tokens) > 1 {
		args = strings.Join(tokens[1:], " ")
	}
	displayName := deriveRunDisplayName(valueName, headExe)

	resolved := resolveWrappedExecutableWithContext(headExe, displayName, args, filepath.Dir(headExe))
	if resolved == "" || !strings.EqualFold(filepath.Ext(resolved), ".exe") {
		return "", ""
	}
	return resolved, displayName
}

// deriveRunDisplayName picks a human-readable name from the Run-key value
// name, stripping common Squirrel prefixes ("com.squirrel.<App>.<App>").
// Falls back to the head exe's basename.
func deriveRunDisplayName(valueName, headExe string) string {
	name := strings.TrimSpace(valueName)
	const sq = "com.squirrel."
	if strings.HasPrefix(name, sq) {
		rest := name[len(sq):]
		// "com.squirrel.<App>.<App>" → take the part after the last dot.
		if idx := strings.LastIndex(rest, "."); idx >= 0 && idx < len(rest)-1 {
			rest = rest[idx+1:]
		}
		name = rest
	}
	if name == "" {
		name = filepathBaseNoExt(headExe)
	}
	return name
}

// collectAppsFromSquirrelLocalAppData walks %LOCALAPPDATA% one level deep
// looking for the Squirrel pattern: <AppDir>\Update.exe with the actual
// app exe at <AppDir>\<AppName>.exe (older Squirrel) or
// <AppDir>\<current|app-X.Y.Z>\<AppName>.exe (newer Squirrel). Backstop
// for Squirrel apps that don't show up in Start Menu or Run.
func collectAppsFromSquirrelLocalAppData(seen map[string]bool, cb Callback) []*AppData {
	localAppData := strings.TrimSpace(os.Getenv("LOCALAPPDATA"))
	if localAppData == "" {
		return nil
	}
	entries, err := os.ReadDir(localAppData)
	if err != nil {
		slog.Warn("squirrel scan: unable to read LOCALAPPDATA", "dir", localAppData, "err", err)
		return nil
	}

	var out []*AppData
	var scanned, kept, droppedNoExe, droppedSystem, droppedSelf, droppedUtility, droppedDuplicate int

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		appDir := filepath.Join(localAppData, entry.Name())
		updateExe := filepath.Join(appDir, "Update.exe")
		if !fileExists(updateExe) {
			continue
		}
		scanned++

		displayName := entry.Name()
		exePath := findSquirrelAppExe(appDir, displayName)
		if exePath == "" {
			droppedNoExe++
			continue
		}

		if isWindowsSystemApp(exePath, displayName) {
			droppedSystem++
			continue
		}
		if isLanternSelfApp(exePath, displayName) {
			droppedSelf++
			continue
		}
		if isWindowsUtilityApp(exePath, displayName) {
			droppedUtility++
			continue
		}

		key := normalizeKey(exePath)
		if seen[key] {
			droppedDuplicate++
			continue
		}
		seen[key] = true

		app := &AppData{
			Name:     displayName,
			BundleID: exePath,
			AppPath:  exePath,
		}
		if cb != nil {
			cb(app)
		}
		out = append(out, app)
		kept++
	}

	slog.Info(
		"squirrel localappdata scan complete",
		"localAppData", localAppData,
		"scanned", scanned,
		"kept", kept,
		"droppedNoExe", droppedNoExe,
		"droppedSystem", droppedSystem,
		"droppedSelf", droppedSelf,
		"droppedUtility", droppedUtility,
		"droppedDuplicate", droppedDuplicate,
		"sampleKept", sampleAppNames(out, 20),
	)
	return out
}

// findSquirrelAppExe locates the real app exe inside a Squirrel install
// directory. Tries (in order): a sibling <AppName>.exe, then any app-* /
// current subdir's <AppName>.exe, then any non-excluded .exe in the
// dir/subdirs. Returns "" if nothing usable is found.
func findSquirrelAppExe(appDir, appName string) string {
	candidates := []string{
		filepath.Join(appDir, appName+".exe"),
	}
	subEntries, err := os.ReadDir(appDir)
	if err == nil {
		for _, se := range subEntries {
			if !se.IsDir() {
				continue
			}
			lower := strings.ToLower(se.Name())
			if strings.HasPrefix(lower, "app-") || lower == "current" {
				candidates = append(candidates, filepath.Join(appDir, se.Name(), appName+".exe"))
			}
		}
	}
	for _, c := range candidates {
		if fileExists(c) {
			return c
		}
	}
	// Fallback: any non-excluded, non-Update .exe in appDir or its app-* subdirs.
	searchDirs := []string{appDir}
	if err == nil {
		for _, se := range subEntries {
			if !se.IsDir() {
				continue
			}
			lower := strings.ToLower(se.Name())
			if strings.HasPrefix(lower, "app-") || lower == "current" {
				searchDirs = append(searchDirs, filepath.Join(appDir, se.Name()))
			}
		}
	}
	for _, dir := range searchDirs {
		ents, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range ents {
			if e.IsDir() || !strings.EqualFold(filepath.Ext(e.Name()), ".exe") {
				continue
			}
			base := strings.TrimSuffix(e.Name(), filepath.Ext(e.Name()))
			if isExcludedName(base) {
				continue
			}
			return filepath.Join(dir, e.Name())
		}
	}
	return ""
}

func filepathBaseNoExt(p string) string {
	b := filepath.Base(p)
	return strings.TrimSuffix(b, filepath.Ext(b))
}

func pickExePath(displayIcon, installLoc string) string {
	if p := parseDisplayIcon(displayIcon); p != "" {
		if fileExists(p) && strings.EqualFold(filepath.Ext(p), ".exe") {
			return p
		}
	}

	installLoc = strings.TrimSpace(expandPercentEnv(installLoc))
	if installLoc == "" {
		return ""
	}
	if st, err := os.Stat(installLoc); err == nil && st.IsDir() {
		entries, err := os.ReadDir(installLoc)
		if err == nil {
			for _, e := range entries {
				if e.IsDir() {
					continue
				}
				n := strings.ToLower(e.Name())
				if strings.HasSuffix(n, ".exe") {
					full := filepath.Join(installLoc, e.Name())
					return full
				}
			}
		}
	}
	return ""
}

func readUninstallEntryMetadata(sk registry.Key) uninstallEntryMetadata {
	metadata := uninstallEntryMetadata{}

	if value, _, err := sk.GetIntegerValue("SystemComponent"); err == nil {
		metadata.systemComponentSet = true
		metadata.systemComponent = value
	}
	if value, _, err := sk.GetIntegerValue("NoDisplay"); err == nil {
		metadata.noDisplaySet = true
		metadata.noDisplay = value
	}
	if value, _, err := sk.GetStringValue("ReleaseType"); err == nil {
		metadata.releaseType = strings.TrimSpace(value)
	}
	// ParentKeyName intentionally not read — see isNonUserFacingUninstallEntry.

	return metadata
}

func isNonUserFacingUninstallEntry(metadata uninstallEntryMetadata) bool {
	if metadata.systemComponentSet && metadata.systemComponent != 0 {
		return true
	}
	if metadata.noDisplaySet && metadata.noDisplay != 0 {
		return true
	}
	// ParentKeyName is NOT a reliable "non-user-facing" signal — Squirrel
	// apps (Slack, Discord, VS Code Insiders), winget packages, and MSI
	// bundle children all set it on legitimate user apps. SystemComponent=1
	// and NoDisplay=1 are the documented signals; that's enough.
	// See Freshdesk #173774 / engineering#3335.
	if metadata.releaseType != "" {
		releaseType := strings.ToLower(metadata.releaseType)
		if strings.Contains(releaseType, "update") ||
			strings.Contains(releaseType, "hotfix") ||
			strings.Contains(releaseType, "security") {
			return true
		}
	}

	return false
}

func shortcutDisplayName(shortcutFileName, targetExe string) string {
	name := strings.TrimSpace(shortcutFileName)
	ext := filepath.Ext(name)
	if strings.EqualFold(ext, ".lnk") {
		name = strings.TrimSuffix(name, ext)
	}
	name = strings.TrimSpace(name)
	if name == "" {
		name = filepathBaseNoExt(targetExe)
	}
	return name
}

func resolveWrappedExecutable(exePath, nameHint string) string {
	return resolveWrappedExecutableWithContext(exePath, nameHint, "", "")
}

func (hint shortcutRecoveryHint) isValid() bool {
	return strings.TrimSpace(hint.displayName) != "" && len(hint.normalizedCandidates) > 0
}

func (hint shortcutRecoveryHint) key() string {
	return normalizeKey(strings.TrimSpace(hint.displayName))
}

func shortcutRecoveryHintFromShortcut(name, shortcutArgs string) shortcutRecoveryHint {
	hint := shortcutRecoveryHint{
		displayName: strings.TrimSpace(name),
	}
	processStartHint := processStartExecutableHint(shortcutArgs)
	appXHints := appxHintsFromShortcutArgs(shortcutArgs)

	hint.normalizedCandidates = appendNormalizedHints(hint.normalizedCandidates, processStartHint)
	hint.normalizedCandidates = appendNormalizedHints(hint.normalizedCandidates, appXHints...)
	if len(hint.normalizedCandidates) > 0 {
		hint.normalizedCandidates = appendNormalizedHints(hint.normalizedCandidates, name)
	}
	return hint
}

func appxHintsFromShortcutArgs(shortcutArgs string) []string {
	trimmed := strings.TrimSpace(shortcutArgs)
	if trimmed == "" {
		return nil
	}

	lower := strings.ToLower(trimmed)
	const marker = "appsfolder\\"
	idx := strings.Index(lower, marker)
	if idx < 0 {
		return nil
	}

	tail := strings.TrimSpace(trimmed[idx+len(marker):])
	tail = strings.Trim(tail, `"'`)
	if tail == "" {
		return nil
	}

	for i, r := range tail {
		if r == ' ' || r == '\t' {
			tail = tail[:i]
			break
		}
	}
	tail = strings.TrimSpace(strings.Trim(tail, `"'`))
	if tail == "" {
		return nil
	}

	hints := []string{tail}
	if bang := strings.Index(tail, "!"); bang > 0 && bang < len(tail)-1 {
		packageID := strings.TrimSpace(tail[:bang])
		appID := strings.TrimSpace(tail[bang+1:])
		if packageID != "" {
			hints = append(hints, packageID)
		}
		if appID != "" {
			hints = append(hints, appID)
			if !strings.EqualFold(filepath.Ext(appID), ".exe") {
				hints = append(hints, appID+".exe")
			}
		}
	}
	return hints
}

func appendNormalizedHints(candidates []string, values ...string) []string {
	for _, value := range values {
		normalized := normalizeExecutableHint(value)
		if normalized == "" {
			continue
		}
		alreadyAdded := false
		for _, existing := range candidates {
			if existing == normalized {
				alreadyAdded = true
				break
			}
		}
		if !alreadyAdded {
			candidates = append(candidates, normalized)
		}
	}
	return candidates
}

func matchesAnyNormalizedHint(value string, candidates []string) bool {
	value = strings.TrimSpace(value)
	if value == "" {
		return false
	}
	for _, candidate := range candidates {
		if candidate == "" {
			continue
		}
		if value == candidate || strings.Contains(value, candidate) || strings.Contains(candidate, value) {
			return true
		}
	}
	return false
}

func windowsPackageDirs() []string {
	localAppData := strings.TrimSpace(os.Getenv("LOCALAPPDATA"))
	if localAppData == "" {
		return nil
	}
	packagesRoot := filepath.Join(localAppData, "Packages")
	entries, err := os.ReadDir(packagesRoot)
	if err != nil {
		return nil
	}
	dirs := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		dirs = append(dirs, filepath.Join(packagesRoot, entry.Name()))
	}
	return dirs
}

func collectAppsFromPackageCacheHints(hints map[string]shortcutRecoveryHint, seen map[string]bool, cb Callback) []*AppData {
	packageDirs := windowsPackageDirs()
	if len(packageDirs) == 0 {
		return nil
	}

	keys := make([]string, 0, len(hints))
	for key := range hints {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	var out []*AppData
	for _, key := range keys {
		hint := hints[key]
		if !hint.isValid() {
			continue
		}
		if isLikelySystemDisplayName(hint.displayName) {
			continue
		}

		exePath := resolvePackageCacheExecutable(packageDirs, hint)
		if exePath == "" {
			continue
		}
		if isWindowsSystemApp(exePath, hint.displayName) {
			continue
		}
		if isWindowsUtilityApp(exePath, hint.displayName) {
			continue
		}
		if isExcludedName(filepathBaseNoExt(exePath)) {
			continue
		}

		keyPath := normalizeKey(exePath)
		if keyPath == "" || seen[keyPath] {
			continue
		}

		app := &AppData{
			Name:     hint.displayName,
			BundleID: exePath,
			AppPath:  exePath,
			IconPath: exePath,
		}

		if cb != nil {
			cb(app)
		}
		out = append(out, app)
		seen[keyPath] = true
	}

	return out
}

func resolvePackageCacheExecutable(packageDirs []string, hint shortcutRecoveryHint) string {
	if !hint.isValid() || len(packageDirs) == 0 {
		return ""
	}

	prioritized := make([]string, 0, len(packageDirs))
	fallback := make([]string, 0, len(packageDirs))
	for _, packageDir := range packageDirs {
		packageName := normalizeExecutableHint(filepath.Base(packageDir))
		if matchesAnyNormalizedHint(packageName, hint.normalizedCandidates) {
			prioritized = append(prioritized, packageDir)
			continue
		}
		fallback = append(fallback, packageDir)
	}

	searchDirs := append(prioritized, fallback...)
	for _, packageDir := range searchDirs {
		localCacheDir := filepath.Join(packageDir, "LocalCache")
		if !dirExists(localCacheDir) {
			continue
		}
		if match := findExecutableInTree(localCacheDir, hint.normalizedCandidates, packageCacheSearchDepth); match != "" {
			return match
		}
	}
	return ""
}

func pathDepth(root, path string) int {
	rel, err := filepath.Rel(root, path)
	if err != nil || rel == "." {
		return 0
	}
	segments := strings.Split(rel, string(os.PathSeparator))
	return len(segments)
}

func findExecutableInTree(root string, normalizedCandidates []string, maxDepth int) string {
	var match string
	_ = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil || d == nil {
			return nil
		}
		if d.IsDir() {
			if pathDepth(root, path) > maxDepth {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.EqualFold(filepath.Ext(d.Name()), ".exe") {
			return nil
		}

		base := filepathBaseNoExt(d.Name())
		if isExcludedName(base) {
			return nil
		}

		normalizedBase := normalizeExecutableHint(base)
		if !matchesAnyNormalizedHint(normalizedBase, normalizedCandidates) {
			return nil
		}

		match = path
		return fs.SkipAll
	})
	return match
}

func resolveShortcutExecutable(targetExe, iconFile, shortcutPath, nameHint, shortcutArgs, shortcutWorkingDir string) string {
	candidates := make([]string, 0, 2)
	if normalized := normalizeShortcutExecutablePath(targetExe, shortcutWorkingDir, shortcutPath); normalized != "" {
		candidates = append(candidates, normalized)
	}
	if normalized := normalizeShortcutExecutablePath(iconFile, shortcutWorkingDir, shortcutPath); normalized != "" {
		if !containsNormalizedPath(candidates, normalized) {
			candidates = append(candidates, normalized)
		}
	}

	for _, candidate := range candidates {
		resolved := resolveWrappedExecutableWithContext(
			candidate,
			nameHint,
			shortcutArgs,
			shortcutWorkingDir,
		)
		if resolved == "" {
			continue
		}
		if !strings.EqualFold(filepath.Ext(resolved), ".exe") {
			continue
		}
		if isExcludedName(filepathBaseNoExt(resolved)) {
			continue
		}
		if isWindowsSystemApp(resolved, nameHint) {
			continue
		}
		return resolved
	}

	return ""
}

func normalizeShortcutExecutablePath(pathValue, shortcutWorkingDir, shortcutPath string) string {
	pathValue = strings.Trim(strings.TrimSpace(pathValue), `"`)
	if pathValue == "" {
		return ""
	}

	pathValue = filepath.Clean(expandPercentEnv(pathValue))
	if !strings.EqualFold(filepath.Ext(pathValue), ".exe") {
		return ""
	}

	if !filepath.IsAbs(pathValue) {
		workingDir := strings.Trim(strings.TrimSpace(shortcutWorkingDir), `"`)
		if workingDir != "" {
			workingDir = filepath.Clean(expandPercentEnv(workingDir))
			if filepath.IsAbs(workingDir) {
				pathValue = filepath.Clean(filepath.Join(workingDir, pathValue))
			}
		}
	}
	if !filepath.IsAbs(pathValue) && strings.TrimSpace(shortcutPath) != "" {
		shortcutDir := filepath.Dir(filepath.Clean(shortcutPath))
		if filepath.IsAbs(shortcutDir) {
			pathValue = filepath.Clean(filepath.Join(shortcutDir, pathValue))
		}
	}
	if !filepath.IsAbs(pathValue) || !fileExists(pathValue) {
		return ""
	}

	return pathValue
}

func resolveWrappedExecutableWithContext(exePath, nameHint, shortcutArgs, shortcutWorkingDir string) string {
	exePath = strings.Trim(strings.TrimSpace(exePath), `"`)
	if exePath == "" {
		return ""
	}

	exePath = filepath.Clean(exePath)
	if !filepath.IsAbs(exePath) {
		return ""
	}

	baseName := filepathBaseNoExt(exePath)
	if !isExcludedName(baseName) {
		return exePath
	}

	appDir := filepath.Dir(exePath)
	if appDir == "" || appDir == "." {
		return ""
	}

	normalizedHint := normalizeExecutableHint(nameHint)
	searchDirs := wrappedExecutableSearchDirs(appDir, shortcutWorkingDir)
	processStartHint := processStartExecutableHint(shortcutArgs)
	if processStartHint != "" {
		for _, dir := range searchDirs {
			candidate := filepath.Clean(filepath.Join(dir, processStartHint))
			if fileExists(candidate) && strings.EqualFold(filepath.Ext(candidate), ".exe") {
				return candidate
			}
		}
	}

	candidates := make([]string, 0, 8)
	seen := make(map[string]bool, 8)
	for _, dir := range searchDirs {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if entry.IsDir() || !strings.EqualFold(filepath.Ext(entry.Name()), ".exe") {
				continue
			}

			candidateName := strings.TrimSuffix(entry.Name(), filepath.Ext(entry.Name()))
			if isExcludedName(candidateName) {
				continue
			}

			candidatePath := filepath.Join(dir, entry.Name())
			key := normalizeKey(candidatePath)
			if seen[key] {
				continue
			}
			seen[key] = true

			if normalizedHint != "" && normalizeExecutableHint(candidateName) == normalizedHint {
				return candidatePath
			}
			candidates = append(candidates, candidatePath)
		}
	}

	if len(candidates) == 1 {
		return candidates[0]
	}

	return ""
}

func wrappedExecutableSearchDirs(appDir, shortcutWorkingDir string) []string {
	searchDirs := []string{appDir}
	workingDir := strings.Trim(strings.TrimSpace(shortcutWorkingDir), `"`)
	workingDir = filepath.Clean(expandPercentEnv(workingDir))
	if workingDir != "" && filepath.IsAbs(workingDir) && dirExists(workingDir) && !containsNormalizedPath(searchDirs, workingDir) {
		searchDirs = append(searchDirs, workingDir)
	}

	appendNested := func(root string) {
		entries, err := os.ReadDir(root)
		if err != nil {
			return
		}

		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}
			dirName := strings.ToLower(strings.TrimSpace(entry.Name()))
			if strings.HasPrefix(dirName, "app-") || dirName == "current" {
				candidate := filepath.Join(root, entry.Name())
				if !containsNormalizedPath(searchDirs, candidate) {
					searchDirs = append(searchDirs, candidate)
				}
			}
		}
	}

	appendNested(appDir)
	if workingDir != "" && filepath.IsAbs(workingDir) {
		appendNested(workingDir)
	}

	return searchDirs
}

func containsNormalizedPath(paths []string, candidate string) bool {
	key := normalizeKey(filepath.Clean(candidate))
	for _, path := range paths {
		if normalizeKey(filepath.Clean(path)) == key {
			return true
		}
	}
	return false
}

func processStartExecutableHint(shortcutArgs string) string {
	tokens := parseWindowsCommandTokens(shortcutArgs)
	for i := 0; i < len(tokens)-1; i++ {
		flag := strings.ToLower(strings.TrimSpace(tokens[i]))
		if flag == "--processstart" || flag == "/processstart" {
			next := strings.Trim(strings.TrimSpace(tokens[i+1]), `"`)
			if next == "" {
				return ""
			}
			if !strings.EqualFold(filepath.Ext(next), ".exe") {
				next += ".exe"
			}
			return next
		}
	}
	return ""
}

func parseWindowsCommandTokens(command string) []string {
	command = strings.TrimSpace(command)
	if command == "" {
		return nil
	}

	var tokens []string
	var current strings.Builder
	inQuotes := false
	for _, r := range command {
		switch r {
		case '"':
			inQuotes = !inQuotes
		case ' ', '\t':
			if inQuotes {
				current.WriteRune(r)
			} else if current.Len() > 0 {
				tokens = append(tokens, current.String())
				current.Reset()
			}
		default:
			current.WriteRune(r)
		}
	}
	if current.Len() > 0 {
		tokens = append(tokens, current.String())
	}
	return tokens
}

func normalizeExecutableHint(name string) string {
	name = strings.TrimSuffix(strings.ToLower(strings.TrimSpace(name)), ".exe")
	var b strings.Builder
	b.Grow(len(name))
	for _, r := range name {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func parseDisplayIcon(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}

	s = expandPercentEnv(s)
	s = strings.Trim(s, `"`)

	// strip ",<index>"
	if i := strings.LastIndex(s, ","); i > 0 {
		tail := strings.TrimSpace(s[i+1:])
		if tail != "" && len(tail) <= 5 {
			if _, err := strconv.Atoi(tail); err == nil {
				s = strings.TrimSpace(strings.Trim(s[:i], `"`))
			}
		}
	}

	ext := strings.ToLower(filepath.Ext(s))
	switch ext {
	case ".exe", ".dll", ".ico":
		return s
	default:
		return ""
	}
}

func expandPercentEnv(s string) string {
	// replace %VAR% with os.Getenv(VAR)
	for {
		start := strings.Index(s, "%")
		if start < 0 {
			break
		}
		end := strings.Index(s[start+1:], "%")
		if end < 0 {
			break
		}
		end = start + 1 + end
		key := s[start+1 : end]
		val := os.Getenv(key)
		s = s[:start] + val + s[end+1:]
	}
	return s
}

func fileExists(p string) bool {
	if p == "" {
		return false
	}
	_, err := os.Stat(p)
	return err == nil
}

func dirExists(p string) bool {
	if p == "" {
		return false
	}
	st, err := os.Stat(p)
	if err != nil {
		return false
	}
	return st.IsDir()
}

func getAppID(appPath string) (string, error) {
	return appPath, nil
}
