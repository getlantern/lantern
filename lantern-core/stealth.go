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
)

func IsStealthBuild() bool {
	if buildBool(StealthBuild) {
		return true
	}
	return buildBool(firstNonEmpty(
		os.Getenv("LANTERN_STEALTH_BUILD"),
		os.Getenv("STEALTH_BUILD"),
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

// EffectiveTelemetryConsent returns the telemetry consent that should be used
// after applying stealth-build policy.
//
// For stealth builds telemetry is unconditionally disabled regardless of any
// prior user opt-in: telemetry is a deanonymization surface and must not be
// emitted from a stealth artifact.  For normal builds the caller-supplied
// consent value is returned unchanged.
func EffectiveTelemetryConsent(configured bool) bool {
	if IsStealthBuild() {
		return false
	}
	return configured
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
