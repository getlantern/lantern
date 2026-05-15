package lanterncore

import "testing"

func clearStealthEnv(t *testing.T) {
	t.Setenv("LANTERN_STEALTH_BUILD", "")
	t.Setenv("STEALTH_BUILD", "")
	t.Setenv("LANTERN_STEALTH_LOG_LEVEL", "")
	t.Setenv("STEALTH_LOG_LEVEL", "")
	t.Setenv("LANTERN_STEALTH_TELEMETRY_DEFAULT_ENABLED", "")
	t.Setenv("STEALTH_TELEMETRY_DEFAULT_ENABLED", "")
}

func TestEffectiveLogLevelNonStealthPreservesDefaultTrace(t *testing.T) {
	clearStealthEnv(t)
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
	clearStealthEnv(t)
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
	clearStealthEnv(t)
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

func TestIsStealthBuildLinkedValueCannotBeDisabledByEnv(t *testing.T) {
	clearStealthEnv(t)
	t.Setenv("LANTERN_STEALTH_BUILD", "false")
	t.Setenv("STEALTH_BUILD", "false")
	origStealthBuild := StealthBuild
	StealthBuild = "true"
	t.Cleanup(func() { StealthBuild = origStealthBuild })

	if !IsStealthBuild() {
		t.Fatal("linked stealth build should remain enabled despite false env fallbacks")
	}
}

func TestEffectiveTelemetryConsent(t *testing.T) {
	clearStealthEnv(t)
	origStealthBuild := StealthBuild
	t.Cleanup(func() {
		StealthBuild = origStealthBuild
	})

	StealthBuild = "false"
	if got := EffectiveTelemetryConsent(false); got {
		t.Fatal("non-stealth false consent should remain false")
	}
	if got := EffectiveTelemetryConsent(true); !got {
		t.Fatal("explicit true consent should remain true")
	}

	StealthBuild = "true"
	if got := EffectiveTelemetryConsent(false); got {
		t.Fatal("stealth false consent should preserve explicit opt-out")
	}

	t.Setenv("LANTERN_STEALTH_TELEMETRY_DEFAULT_ENABLED", "true")
	t.Setenv("STEALTH_TELEMETRY_DEFAULT_ENABLED", "true")
	if got := EffectiveTelemetryConsent(false); got {
		t.Fatal("stealth telemetry env defaults must not override explicit opt-out")
	}
}
