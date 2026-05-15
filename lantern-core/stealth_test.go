package lanterncore

import "testing"

func TestEffectiveLogLevelNonStealthPreservesDefaultTrace(t *testing.T) {
	t.Setenv("LANTERN_STEALTH_BUILD", "")
	t.Setenv("STEALTH_BUILD", "")
	origStealthBuild := StealthBuild
	StealthBuild = "false"
	t.Cleanup(func() { StealthBuild = origStealthBuild })

	if got := EffectiveLogLevel(""); got != DefaultLogLevel {
		t.Fatalf("EffectiveLogLevel(\"\") = %q, want %q", got, DefaultLogLevel)
	}
	if got := EffectiveLogLevel("debug"); got != "debug" {
		t.Fatalf("EffectiveLogLevel(\"debug\") = %q, want debug", got)
	}
}

func TestEffectiveLogLevelStealthReplacesTraceDefault(t *testing.T) {
	t.Setenv("STEALTH_BUILD", "true")
	t.Setenv("STEALTH_LOG_LEVEL", "")
	origStealthBuild := StealthBuild
	origStealthLogLevel := StealthLogLevel
	StealthBuild = "false"
	StealthLogLevel = "warn"
	t.Cleanup(func() {
		StealthBuild = origStealthBuild
		StealthLogLevel = origStealthLogLevel
	})

	for _, configured := range []string{"", "trace", "TRACE"} {
		if got := EffectiveLogLevel(configured); got != safeStealthLogLevel {
			t.Fatalf("EffectiveLogLevel(%q) = %q, want %q", configured, got, safeStealthLogLevel)
		}
	}
	if got := EffectiveLogLevel("error"); got != "error" {
		t.Fatalf("EffectiveLogLevel(\"error\") = %q, want error", got)
	}
}

func TestEffectiveLogLevelStealthRejectsTraceFallback(t *testing.T) {
	t.Setenv("STEALTH_BUILD", "true")
	t.Setenv("STEALTH_LOG_LEVEL", "trace")
	origStealthBuild := StealthBuild
	origStealthLogLevel := StealthLogLevel
	StealthBuild = "false"
	StealthLogLevel = "trace"
	t.Cleanup(func() {
		StealthBuild = origStealthBuild
		StealthLogLevel = origStealthLogLevel
	})

	if got := EffectiveLogLevel(""); got != safeStealthLogLevel {
		t.Fatalf("EffectiveLogLevel(\"\") = %q, want %q", got, safeStealthLogLevel)
	}
}

func TestEffectiveTelemetryConsent(t *testing.T) {
	origStealthBuild := StealthBuild
	origTelemetryDefault := StealthTelemetryDefaultEnabled
	t.Cleanup(func() {
		StealthBuild = origStealthBuild
		StealthTelemetryDefaultEnabled = origTelemetryDefault
	})

	StealthBuild = "false"
	t.Setenv("STEALTH_BUILD", "")
	if got := EffectiveTelemetryConsent(false); got {
		t.Fatal("non-stealth false consent should remain false")
	}
	if got := EffectiveTelemetryConsent(true); !got {
		t.Fatal("explicit true consent should remain true")
	}

	StealthBuild = "true"
	StealthTelemetryDefaultEnabled = "false"
	if got := EffectiveTelemetryConsent(false); got {
		t.Fatal("stealth false consent should default to false")
	}

	StealthTelemetryDefaultEnabled = "true"
	if got := EffectiveTelemetryConsent(false); !got {
		t.Fatal("stealth telemetry build default should allow explicit opt-in default")
	}
}
