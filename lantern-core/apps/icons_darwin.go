//go:build darwin && !ios

package apps

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	resourcesPath := filepath.Join(appPath, "Contents", "Resources")
	entries, err := os.ReadDir(resourcesPath)
	if err != nil && !os.IsNotExist(err) {
		return "", fmt.Errorf("read icon directory: %w", err)
	}
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".icns") {
			return filepath.Join(resourcesPath, entry.Name()), nil
		}
	}
	return wrappedIconPath(appPath), nil
}

// wrappedIconPath picks the largest AppIcon*.png from an iPhone/iPad bundle's
// inner .app. Those bundles carry no .icns; sips resizes PNG just as well.
func wrappedIconPath(appPath string) string {
	plistPath, wrapped := bundleInfoPlist(appPath)
	if wrapped == "" {
		return ""
	}
	iconDir := filepath.Dir(plistPath)
	entries, err := os.ReadDir(iconDir)
	if err != nil {
		return ""
	}
	best, bestSize := "", int64(-1)
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasPrefix(entry.Name(), "AppIcon") || !strings.HasSuffix(entry.Name(), ".png") {
			continue
		}
		iconPath := filepath.Join(iconDir, entry.Name())
		if info, err := os.Stat(iconPath); err == nil && !info.IsDir() && info.Size() > bestSize {
			best, bestSize = iconPath, info.Size()
		}
	}
	return best
}

func getIconBytes(appPath string) ([]byte, error) {
	iconPath, err := getIconPath(appPath)
	if err != nil || iconPath == "" {
		return nil, err
	}

	tmpDir, err := os.MkdirTemp("", "appicon-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(tmpDir)

	outPng := filepath.Join(tmpDir, "icon.png")

	const size = 64

	cmd := exec.Command(
		"/usr/bin/sips",
		"-Z", strconv.Itoa(size),
		// output as PNG
		"-s", "format", "png",
		iconPath,
		"--out", outPng,
	)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("sips convert failed: %w (%s)", err, stderr.String())
	}

	b, err := os.ReadFile(outPng)
	if err != nil {
		return nil, err
	}
	return b, nil
}
