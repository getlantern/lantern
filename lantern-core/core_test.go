package lanterncore

import (
	"bytes"
	"os"
	"path/filepath"
	"regexp"
	"testing"

	"github.com/getlantern/radiance/issue"
)

// The cases must cover every key the app's report-issue dropdown submits
// (lib/features/report_issue/report_issue.dart issueOptions); an unmatched
// key silently files the ticket as Other (getlantern/engineering#3839).
func TestParseIssueType(t *testing.T) {
	for s, want := range map[string]issue.IssueType{
		"cannot_complete_purchase":    issue.CannotCompletePurchase,
		"cannot_sign_in":              issue.CannotSignIn,
		"spinner_loads_endlessly":     issue.SpinnerLoadsEndlessly,
		"cannot_access_blocked_sites": issue.CannotAccessBlockedSites,
		"slow":                        issue.Slow,
		"cannot_link_device":          issue.CannotLinkDevice,
		"cannot_link_devices":         issue.CannotLinkDevice,
		"application_crashes":         issue.ApplicationCrashes,
		"update_fails":                issue.UpdateFails,
		"other":                       issue.Other,
		"Slow":                        issue.Slow,
		"Cannot sign in":              issue.Other,
		"":                            issue.Other,
	} {
		if got := parseIssueType(s); got != want {
			t.Errorf("parseIssueType(%q) = %v, want %v", s, got, want)
		}
	}
}

// TestIssueOptionsMatchParser guards the app→core contract that broke in
// getlantern/engineering#3839: the dropdown must submit raw underscore keys,
// every key must be recognized by parseIssueType, and every key must have a
// translation. It reads issueOptions out of the Dart source so a rename or
// re-translation on either side fails here instead of silently filing every
// report as Other.
func TestIssueOptionsMatchParser(t *testing.T) {
	src, err := os.ReadFile(
		filepath.Join("..", "lib", "features", "report_issue", "report_issue.dart"))
	if err != nil {
		t.Fatalf("reading report_issue.dart (moved? update this test): %v", err)
	}

	m := regexp.MustCompile(`(?s)issueOptions => <String>\[(.*?)\]`).FindSubmatch(src)
	if m == nil {
		t.Fatal("issueOptions list not found in report_issue.dart; update this test")
	}
	if bytes.Contains(m[1], []byte(".i18n")) {
		t.Fatal("issueOptions must hold raw keys, translated only at render " +
			"time — a translated value never matches parseIssueType")
	}

	keys := regexp.MustCompile(`'([a-z_]+)'`).FindAllSubmatch(m[1], -1)
	if len(keys) < 5 {
		t.Fatalf("extracted only %d issue keys; extraction broken?", len(keys))
	}

	po, err := os.ReadFile(filepath.Join("..", "assets", "locales", "en.po"))
	if err != nil {
		t.Fatalf("reading en.po: %v", err)
	}

	for _, k := range keys {
		key := string(k[1])
		if key != "other" && parseIssueType(key) == issue.Other {
			t.Errorf("dropdown key %q unrecognized by parseIssueType; "+
				"reports would file as Other", key)
		}
		if !bytes.Contains(po, []byte(`msgid "`+key+`"`)) {
			t.Errorf("dropdown key %q has no msgid in en.po; "+
				"the dropdown would render the raw key", key)
		}
	}
}
