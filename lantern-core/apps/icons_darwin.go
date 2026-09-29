//go:build darwin && !ios

package apps

import (
	"bytes"
	"fmt"
	"image"
	_ "image/png"
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

// wrappedIconPath picks the AppIcon*.png with the most pixels from an
// iPhone/iPad bundle's inner .app. Those bundles carry no .icns; sips resizes
// PNG just as well. Ranking is by raster size, not byte size: a detailed
// small icon can encode to more bytes than a flat large one.
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
	best, bestPixels := "", -1
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasPrefix(entry.Name(), "AppIcon") || !strings.HasSuffix(entry.Name(), ".png") {
			continue
		}
		iconPath := filepath.Join(iconDir, entry.Name())
		if pixels := pngPixels(iconPath); pixels > bestPixels {
			best, bestPixels = iconPath, pixels
		}
	}
	return best
}

// pngPixels returns width*height from the PNG header, or -1 if the file is
// not a decodable PNG. Only the header is read.
func pngPixels(path string) int {
	f, err := os.Open(path)
	if err != nil {
		return -1
	}
	defer f.Close()
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		return -1
	}
	return cfg.Width * cfg.Height
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
