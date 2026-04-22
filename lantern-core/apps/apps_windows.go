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
	parentKeyName      string
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
		slog.Debug("WScript.Shell not available", "err", err)
		return out
	}
	defer wshObj.Release()

	wsh, err := wshObj.QueryInterface(ole.IID_IDispatch)
	if err != nil {
		return out
	}
	defer wsh.Release()

	for _, root := range startDirs {
		root = strings.TrimSpace(root)
		if root == "" {
			continue
		}
		if st, err := os.Stat(root); err != nil || !st.IsDir() {
			continue
		}

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
				if recoveryHint.isValid() {
					recoveryHints[recoveryHint.key()] = recoveryHint
				}
				return nil
			}
			if isWindowsSystemApp(targetExe, name) {
				if recoveryHint.isValid() {
					recoveryHints[recoveryHint.key()] = recoveryHint
				}
				return nil
			}
			if isExcludedStartMenuShortcutPath(p) || isWindowsUtilityApp(targetExe, name) {
				return nil
			}
			keyPath := normalizeKey(targetExe)
			if seen[keyPath] {
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

	if len(recoveryHints) > 0 {
		recovered := collectAppsFromPackageCacheHints(recoveryHints, seen, cb)
		out = append(out, recovered...)
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

	for _, r := range roots {
		k, err := registry.OpenKey(r.key, r.path, r.flags)
		if err != nil {
			continue
		}

		names, _ := k.ReadSubKeyNames(-1)
		k.Close()

		for _, sub := range names {
			sk, err := registry.OpenKey(r.key, r.path+`\`+sub, r.flags)
			if err != nil {
				continue
			}

			metadata := readUninstallEntryMetadata(sk)
			if isNonUserFacingUninstallEntry(metadata) {
				sk.Close()
				continue
			}

			displayName, _, _ := sk.GetStringValue("DisplayName")
			displayIcon, _, _ := sk.GetStringValue("DisplayIcon")
			installLoc, _, _ := sk.GetStringValue("InstallLocation")
			sk.Close()

			displayName = strings.TrimSpace(displayName)
			if displayName == "" {
				// No name usually indicates an app is “not user-facing”, so skip
				continue
			}

			exePath := pickExePath(displayIcon, installLoc)
			if exePath == "" || !strings.HasSuffix(strings.ToLower(exePath), ".exe") {
				continue
			}
			exePath = resolveWrappedExecutable(exePath, displayName)
			if exePath == "" {
				continue
			}
			if isWindowsSystemApp(exePath, displayName) {
				continue
			}
			if isWindowsUtilityApp(exePath, displayName) {
				continue
			}

			// Don’t show uninstallers/updaters
			if isExcludedName(filepathBaseNoExt(exePath)) {
				continue
			}

			appID := exePath
			keyID := normalizeKey(appID)
			keyPath := normalizeKey(exePath)
			if seen[keyID] || seen[keyPath] {
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

	return out
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
	if value, _, err := sk.GetStringValue("ParentKeyName"); err == nil {
		metadata.parentKeyName = strings.TrimSpace(value)
	}

	return metadata
}

func isNonUserFacingUninstallEntry(metadata uninstallEntryMetadata) bool {
	if metadata.systemComponentSet && metadata.systemComponent != 0 {
		return true
	}
	if metadata.noDisplaySet && metadata.noDisplay != 0 {
		return true
	}
	if metadata.parentKeyName != "" {
		return true
	}
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
