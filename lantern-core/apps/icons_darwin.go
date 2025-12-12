//go:build darwin

package apps

import (
	"bytes"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
)

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	resourcesPath := filepath.Join(appPath, "Contents", "Resources")
	matches, err := filepath.Glob(filepath.Join(resourcesPath, "*.icns"))
	if err != nil {
		wrapped := fmt.Errorf("error globbing icons for %s: %w", appPath, err)
		slog.Error("glob error:", "error", wrapped)
		return "", wrapped
	}
	if len(matches) == 0 {
		return "", nil
	}
	return matches[0], nil
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
