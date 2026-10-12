package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"
)

const fixtureJSON = `{"schema_version":1,"account_environment":"staging","user_id":"9223372036854775806","token":"private-fixture-token","device_id":"private-fixture-device","locale":"fa","auto_report":false,"proxy_all":true,"auto_launch":true,"user_level":"pro"}`

func fixture(t *testing.T) Expected {
	t.Helper()
	expected, err := decodeExpected(strings.NewReader(fixtureJSON))
	if err != nil {
		t.Fatal("valid fixture rejected")
	}
	return expected
}

type fakeClient struct {
	account                        accountFacts
	fresh                          accountFacts
	settings                       settingsFacts
	status                         string
	cachedErr, freshErr, statusErr error
	connectErr, disconnectErr      error
	connects, disconnects          int
	fetches                        int
	stall                          bool
}

func (client *fakeClient) UserData(context.Context) (accountFacts, error) {
	return client.account, client.cachedErr
}
func (client *fakeClient) FetchUserData(context.Context) (accountFacts, error) {
	client.fetches++
	return client.fresh, client.freshErr
}
func (client *fakeClient) Settings(context.Context) (settingsFacts, error) {
	return client.settings, nil
}
func (client *fakeClient) VPNStatus(context.Context) (string, error) {
	return client.status, client.statusErr
}
func (client *fakeClient) ConnectVPN(context.Context) error {
	client.connects++
	if !client.stall {
		client.status = "connected"
	}
	return client.connectErr
}
func (client *fakeClient) DisconnectVPN(context.Context) error {
	client.disconnects++
	if !client.stall {
		client.status = "disconnected"
	}
	return client.disconnectErr
}
func (*fakeClient) Close() {}

func matchingClient(expected Expected) *fakeClient {
	account := accountFacts{Valid: true, UserID: expected.id, NestedID: expected.id,
		Token: expected.Token, NestedToken: expected.Token, DeviceID: expected.DeviceID, UserLevel: expected.UserLevel}
	return &fakeClient{account: account, fresh: account, status: "disconnected", settings: settingsFacts{
		Valid: true, Token: expected.Token, DeviceID: expected.DeviceID, Locale: *expected.Locale,
		UserLevel: expected.UserLevel, AutoReport: *expected.AutoReport,
		SmartRouting: !*expected.ProxyAll, AutoLaunch: *expected.AutoLaunch,
	}}
}

func TestExpectedFixtureRejectsUnsafeOrAmbiguousIdentity(t *testing.T) {
	for name, invalid := range map[string]string{
		"production":               strings.Replace(fixtureJSON, `"staging"`, `"production"`, 1),
		"numeric ID":               strings.Replace(fixtureJSON, `"9223372036854775806"`, `9223372036854775806`, 1),
		"float ID":                 strings.Replace(fixtureJSON, `9223372036854775806`, `9.223372036854776e18`, 1),
		"leading zero":             strings.Replace(fixtureJSON, `9223372036854775806`, `0123`, 1),
		"overflow":                 strings.Replace(fixtureJSON, `9223372036854775806`, `9223372036854775808`, 1),
		"zero":                     strings.Replace(fixtureJSON, `9223372036854775806`, `0`, 1),
		"empty token":              strings.Replace(fixtureJSON, `private-fixture-token`, ``, 1),
		"missing false preference": strings.Replace(fixtureJSON, `"auto_report":false,`, ``, 1),
		"unknown level":            strings.Replace(fixtureJSON, `"pro"`, `"paid"`, 1),
		"unknown field":            strings.Replace(fixtureJSON, `"schema_version":1`, `"schema_version":1,"extra":"secret"`, 1),
		"trailing document":        fixtureJSON + `{}`,
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := decodeExpected(strings.NewReader(invalid)); err == nil {
				t.Fatal("invalid expected fixture accepted")
			}
		})
	}
}

func TestVerifyPreservesLargeIdentityWithoutConnectionChanges(t *testing.T) {
	expected := fixture(t)
	client := matchingClient(expected)
	result := runProbe(context.Background(), "verify", "", expected, client, nil)
	if !result.OK || !result.RemoteAccountVerified || !result.PreferencesMatch || !result.TokenMatch || !result.VPNDisconnected || client.fetches != 1 {
		t.Fatalf("verification failed: %+v", result)
	}
	if client.connects != 0 || client.disconnects != 0 {
		t.Fatal("verification changed VPN state")
	}
	digest := sha256.Sum256([]byte("9223372036854775806\nprivate-fixture-device"))
	if result.IdentitySHA256 != hex.EncodeToString(digest[:]) {
		t.Fatal("identity digest differs from cross-repository contract")
	}
	client.account.UserID--
	result = runProbe(context.Background(), "verify", "", expected, client, nil)
	if result.OK || result.Code != "cached_identity_mismatch" || client.fetches != 1 {
		t.Fatal("adjacent int64 identity was accepted or refreshed")
	}
}

func TestMismatchedIdentityAndEveryPreferenceFailClosed(t *testing.T) {
	expected := fixture(t)
	for name, mutate := range map[string]func(*fakeClient){
		"cached token":       func(client *fakeClient) { client.account.Token = "other" },
		"cached nested ID":   func(client *fakeClient) { client.account.NestedID-- },
		"fresh ID":           func(client *fakeClient) { client.fresh.UserID-- },
		"fresh nested token": func(client *fakeClient) { client.fresh.NestedToken = "other" },
		"fresh device":       func(client *fakeClient) { client.fresh.DeviceID = "other" },
		"fresh pro status":   func(client *fakeClient) { client.fresh.UserLevel = "free" },
		"settings token":     func(client *fakeClient) { client.settings.Token = "other" },
		"settings device":    func(client *fakeClient) { client.settings.DeviceID = "other" },
		"settings locale":    func(client *fakeClient) { client.settings.Locale = "en" },
		"settings telemetry": func(client *fakeClient) { client.settings.AutoReport = true },
		"settings routing":   func(client *fakeClient) { client.settings.SmartRouting = true },
		"settings startup":   func(client *fakeClient) { client.settings.AutoLaunch = false },
		"settings level":     func(client *fakeClient) { client.settings.UserLevel = "free" },
		"missing setting":    func(client *fakeClient) { client.settings.Valid = false },
	} {
		t.Run(name, func(t *testing.T) {
			client := matchingClient(expected)
			mutate(client)
			result := runProbe(context.Background(), "connect", "https://controlled.example/check", expected, client, func(context.Context, string) bool { return true })
			if result.OK || client.connects != 0 {
				t.Fatal("mismatched identity or preferences allowed connection")
			}
		})
	}
}

func TestConnectionRequiresVPNAndHTTPSAndDisconnectConfirmsState(t *testing.T) {
	expected := fixture(t)
	client := matchingClient(expected)
	probes := 0
	check := func(context.Context, string) bool { probes++; return true }
	result := runProbe(context.Background(), "connect", "https://controlled.example/check", expected, client, check)
	if !result.OK || !result.VPNConnected || !result.HTTPSProbeOK || client.connects != 1 || probes != 1 {
		t.Fatalf("connect failed: %+v", result)
	}
	result = runProbe(context.Background(), "disconnect", "", expected, client, nil)
	if !result.OK || !result.VPNDisconnected || client.disconnects != 1 {
		t.Fatalf("disconnect failed: %+v", result)
	}
	client = matchingClient(expected)
	result = runProbe(context.Background(), "connect", "https://controlled.example/check", expected, client, func(context.Context, string) bool { return false })
	if result.OK || result.Code != "https_probe_failed" {
		t.Fatal("failed connectivity reported success")
	}
	client = matchingClient(expected)
	result = runProbe(context.Background(), "connect", "https://controlled.example/check", expected, client, func(context.Context, string) bool { client.status = "disconnected"; return true })
	if result.OK || result.VPNConnected || result.Code != "connection_lost" {
		t.Fatal("connection loss during HTTPS probe reported success")
	}
}

func TestWaitingHonorsDeadline(t *testing.T) {
	expected := fixture(t)
	client := matchingClient(expected)
	client.stall = true
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
	defer cancel()
	result := runProbe(ctx, "connect", "https://controlled.example/check", expected, client, func(context.Context, string) bool { t.Fatal("probe before connected"); return false })
	if result.OK || result.Code != "deadline_exceeded" {
		t.Fatalf("deadline was not enforced: %+v", result)
	}
}

func TestResultsNeverSerializeCredentialsOrRawErrors(t *testing.T) {
	expected := fixture(t)
	for _, failure := range []string{"none", "cached", "remote", "status", "connect", "disconnect"} {
		client := matchingClient(expected)
		privateError := errors.New(expected.Token + expected.DeviceID + expected.UserID + " private@example.test C:\\private\\fixture.json")
		mode := "verify"
		switch failure {
		case "cached":
			client.cachedErr = privateError
		case "remote":
			client.freshErr = privateError
		case "status":
			client.statusErr = privateError
		case "connect":
			mode, client.connectErr = "connect", privateError
		case "disconnect":
			mode, client.status, client.disconnectErr = "disconnect", "connected", privateError
		}
		result := runProbe(context.Background(), mode, "https://controlled.example/check", expected, client, func(context.Context, string) bool { return true })
		data, err := json.Marshal(result)
		if err != nil {
			t.Fatal(err)
		}
		for _, forbidden := range []string{expected.Token, expected.DeviceID, expected.UserID, "private@example.test", "fixture.json"} {
			if bytes.Contains(data, []byte(forbidden)) {
				t.Fatal("result leaked private fixture or error details")
			}
		}
	}
	var output bytes.Buffer
	if command([]string{"--unknown-secret-argument=private-fixture-token"}, &output) == 0 || strings.Contains(output.String(), "private-fixture-token") {
		t.Fatal("invalid CLI argument was accepted or echoed")
	}
	output.Reset()
	if command([]string{"--expected", "C:\\private\\fixture-token.json"}, &output) == 0 || strings.Contains(output.String(), "fixture-token") {
		t.Fatal("private expected path was echoed")
	}
}

func TestProbeURLRejectsCredentialsAndUnencryptedEndpoints(t *testing.T) {
	for _, target := range []string{"", "http://example.com", "https://user:secret@example.com", "https://example.com?token=secret", "https://example.com?", "https://example.com/#secret", "https:opaque", "https:///path"} {
		if validProbeURL(target) {
			t.Fatal("unsafe probe URL accepted")
		}
	}
	if !validProbeURL("https://controlled.example/check") {
		t.Fatal("valid probe URL rejected")
	}
}
