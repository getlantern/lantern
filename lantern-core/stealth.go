package lanterncore

import (
	"os"
	"strings"
)

const (
	// DefaultLogLevel preserves the existing non-stealth production behavior.
	DefaultLogLevel = "trace"

	safeStealthLogLevel = "warn"
)

var (
	// StealthBuild is set by release tooling with:
	//
	//	-X github.com/getlantern/lantern/lantern-core.StealthBuild=true
	//
	// Runtime env fallbacks are kept for local validation until the full
	// native stealth profile plumbing lands in getlantern/lantern#8763.
	StealthBuild = "false"

	// StealthLogLevel is the Go/Radiance fallback log level for stealth builds.
	// Empty and trace-level defaults are deliberately replaced by
	// EffectiveLogLevel.
	StealthLogLevel = safeStealthLogLevel

	// StealthTelemetryDefaultEnabled lets an explicit stealth build opt back in
	// to telemetry. The default remains false.
	StealthTelemetryDefaultEnabled = "false"
)

func IsStealthBuild() bool {
	return buildBool(firstNonEmpty(
		os.Getenv("LANTERN_STEALTH_BUILD"),
		os.Getenv("STEALTH_BUILD"),
		StealthBuild,
	))
}

func EffectiveLogLevel(configured string) string {
	configured = strings.ToLower(strings.TrimSpace(configured))
	if !IsStealthBuild() {
		if configured == "" {
			return DefaultLogLevel
		}
		return configured
	}

	if configured == "" || configured == "trace" {
		return effectiveStealthLogLevel()
	}
	return configured
}

func EffectiveTelemetryConsent(configured bool) bool {
	if configured {
		return true
	}
	if !IsStealthBuild() {
		return false
	}
	return buildBool(firstNonEmpty(
		os.Getenv("LANTERN_STEALTH_TELEMETRY_DEFAULT_ENABLED"),
		os.Getenv("STEALTH_TELEMETRY_DEFAULT_ENABLED"),
		StealthTelemetryDefaultEnabled,
	))
}

func effectiveStealthLogLevel() string {
	level := strings.ToLower(strings.TrimSpace(firstNonEmpty(
		os.Getenv("LANTERN_STEALTH_LOG_LEVEL"),
		os.Getenv("STEALTH_LOG_LEVEL"),
		StealthLogLevel,
	)))
	if level == "" || level == "trace" {
		return safeStealthLogLevel
	}
	return level
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func buildBool(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "y", "on":
		return true
	default:
		return false
	}
}
