//go:build !windows

package apps

// markBrowsers is a no-op outside Windows: Android and macOS detect
// browsers in their platform layers (AppDataHandler.kt queries browsable
// http intent handlers; AppStreamHandler.swift asks LaunchServices).
func markBrowsers([]*AppData) {}
