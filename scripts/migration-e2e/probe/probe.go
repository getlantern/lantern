package main

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
	"unicode"
)

type Expected struct {
	SchemaVersion      int     `json:"schema_version"`
	AccountEnvironment string  `json:"account_environment"`
	UserID             string  `json:"user_id"`
	Token              string  `json:"token"`
	DeviceID           string  `json:"device_id"`
	Locale             *string `json:"locale"`
	AutoReport         *bool   `json:"auto_report"`
	ProxyAll           *bool   `json:"proxy_all"`
	AutoLaunch         *bool   `json:"auto_launch"`
	UserLevel          string  `json:"user_level"`
	id                 int64
}

type Result struct {
	SchemaVersion         int    `json:"schema_version"`
	Phase                 string `json:"phase"`
	OK                    bool   `json:"ok"`
	Code                  string `json:"code"`
	IdentitySHA256        string `json:"identity_sha256,omitempty"`
	IPCReady              bool   `json:"ipc_ready"`
	AccountMatch          bool   `json:"account_match"`
	TokenMatch            bool   `json:"token_match"`
	DeviceMatch           bool   `json:"device_match"`
	PreferencesMatch      bool   `json:"preferences_match"`
	UserLevelMatch        bool   `json:"user_level_match"`
	RemoteAccountVerified bool   `json:"remote_account_verified"`
	VPNConnected          bool   `json:"vpn_connected"`
	VPNDisconnected       bool   `json:"vpn_disconnected"`
	HTTPSProbeOK          bool   `json:"https_probe_ok"`
}

type accountFacts struct {
	Valid               bool
	UserID, NestedID    int64
	Token, NestedToken  string
	DeviceID, UserLevel string
}

type settingsFacts struct {
	Valid                                bool
	Token, DeviceID, Locale, UserLevel   string
	AutoReport, SmartRouting, AutoLaunch bool
}

type serviceClient interface {
	UserData(context.Context) (accountFacts, error)
	FetchUserData(context.Context) (accountFacts, error)
	Settings(context.Context) (settingsFacts, error)
	VPNStatus(context.Context) (string, error)
	ConnectVPN(context.Context) error
	DisconnectVPN(context.Context) error
	Close()
}

func readExpected(path string) (Expected, error) {
	file, err := os.Open(path)
	if err != nil {
		return Expected{}, errors.New("invalid fixture")
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > 64*1024 {
		return Expected{}, errors.New("invalid fixture")
	}
	return decodeExpected(io.LimitReader(file, 64*1024+1))
}

func decodeExpected(reader io.Reader) (Expected, error) {
	var expected Expected
	decoder := json.NewDecoder(reader)
	decoder.DisallowUnknownFields()
	if decoder.Decode(&expected) != nil || decoder.Decode(new(any)) != io.EOF {
		return Expected{}, errors.New("invalid fixture")
	}
	id, err := strconv.ParseInt(expected.UserID, 10, 64)
	if err != nil || id <= 0 || strconv.FormatInt(id, 10) != expected.UserID ||
		expected.SchemaVersion != 1 || expected.AccountEnvironment != "staging" ||
		expected.Locale == nil || expected.AutoReport == nil || expected.ProxyAll == nil || expected.AutoLaunch == nil ||
		(expected.UserLevel != "free" && expected.UserLevel != "pro") ||
		!boundedText(expected.Token, 4096, true) || !boundedText(expected.DeviceID, 256, true) ||
		!boundedText(*expected.Locale, 128, false) {
		return Expected{}, errors.New("invalid fixture")
	}
	expected.id = id
	return expected, nil
}

func boundedText(value string, maximum int, required bool) bool {
	return len(value) <= maximum && (!required || value != "") && strings.IndexFunc(value, unicode.IsControl) < 0
}

func sameToken(first, second string) bool {
	return subtle.ConstantTimeCompare([]byte(first), []byte(second)) == 1
}

func accountMatches(expected Expected, actual accountFacts) bool {
	return actual.Valid && actual.UserID == expected.id && actual.NestedID == expected.id &&
		sameToken(actual.Token, expected.Token) && sameToken(actual.NestedToken, expected.Token) &&
		actual.DeviceID == expected.DeviceID && actual.UserLevel == expected.UserLevel
}

func compare(expected Expected, cached, fresh accountFacts, actual settingsFacts, result *Result) {
	result.AccountMatch = cached.Valid && fresh.Valid && cached.UserID == expected.id && cached.NestedID == expected.id && fresh.UserID == expected.id && fresh.NestedID == expected.id
	result.TokenMatch = sameToken(cached.Token, expected.Token) && sameToken(cached.NestedToken, expected.Token) && sameToken(fresh.Token, expected.Token) && sameToken(fresh.NestedToken, expected.Token) && sameToken(actual.Token, expected.Token)
	result.DeviceMatch = cached.DeviceID == expected.DeviceID && fresh.DeviceID == expected.DeviceID && actual.DeviceID == expected.DeviceID
	result.UserLevelMatch = cached.UserLevel == expected.UserLevel && fresh.UserLevel == expected.UserLevel && actual.UserLevel == expected.UserLevel
	result.PreferencesMatch = actual.Valid && actual.Locale == *expected.Locale && actual.AutoReport == *expected.AutoReport && actual.SmartRouting == !*expected.ProxyAll && actual.AutoLaunch == *expected.AutoLaunch
	result.RemoteAccountVerified = accountMatches(expected, fresh)
}

func runProbe(ctx context.Context, mode, probeURL string, expected Expected, client serviceClient, networkProbe func(context.Context, string) bool) Result {
	digest := sha256.Sum256([]byte(expected.UserID + "\n" + expected.DeviceID))
	result := Result{SchemaVersion: 1, Phase: mode, IdentitySHA256: hex.EncodeToString(digest[:])}
	fail := func(code string) Result {
		result.Code = code
		if ctx.Err() != nil {
			result.Code = "deadline_exceeded"
		}
		return result
	}
	if ctx.Err() != nil {
		return fail("deadline_exceeded")
	}
	cached, err := client.UserData(ctx)
	if err != nil {
		return fail("ipc_unavailable")
	}
	result.IPCReady = true
	if !accountMatches(expected, cached) {
		return fail("cached_identity_mismatch")
	}
	fresh, err := client.FetchUserData(ctx)
	if err != nil {
		return fail("remote_verification_failed")
	}
	actual, err := client.Settings(ctx)
	if err != nil {
		return fail("settings_unavailable")
	}
	compare(expected, cached, fresh, actual, &result)
	if !result.AccountMatch || !result.TokenMatch || !result.DeviceMatch || !result.PreferencesMatch || !result.UserLevelMatch || !result.RemoteAccountVerified {
		return fail("identity_or_settings_mismatch")
	}
	status, err := client.VPNStatus(ctx)
	if err != nil || !validStatus(status) {
		return fail("vpn_status_unavailable")
	}
	result.VPNConnected, result.VPNDisconnected = status == "connected", status == "disconnected"
	switch mode {
	case "connect":
		if !validProbeURL(probeURL) {
			return fail("invalid_probe_url")
		}
		if status != "connected" {
			if err := client.ConnectVPN(ctx); err != nil {
				return fail("connect_failed")
			}
		}
		if !waitStatus(ctx, client, "connected") {
			return fail("connection_not_confirmed")
		}
		result.VPNConnected, result.VPNDisconnected = true, false
		if !networkProbe(ctx, probeURL) {
			return fail("https_probe_failed")
		}
		result.HTTPSProbeOK = true
		status, err = client.VPNStatus(ctx)
		if err != nil || status != "connected" {
			result.VPNConnected = false
			return fail("connection_lost")
		}
	case "disconnect":
		if status != "disconnected" {
			if err := client.DisconnectVPN(ctx); err != nil {
				return fail("disconnect_failed")
			}
		}
		if !waitStatus(ctx, client, "disconnected") {
			return fail("disconnection_not_confirmed")
		}
		result.VPNConnected, result.VPNDisconnected = false, true
	case "verify":
	default:
		return fail("invalid_arguments")
	}
	if ctx.Err() != nil {
		return fail("deadline_exceeded")
	}
	result.OK, result.Code = true, "ok"
	return result
}

func validStatus(status string) bool {
	switch status {
	case "connected", "disconnected", "connecting", "disconnecting", "restarting", "error":
		return true
	default:
		return false
	}
}

func waitStatus(ctx context.Context, client serviceClient, wanted string) bool {
	for {
		if ctx.Err() != nil {
			return false
		}
		status, err := client.VPNStatus(ctx)
		if err != nil || !validStatus(status) || status == "error" {
			return false
		}
		if status == wanted {
			return true
		}
		select {
		case <-ctx.Done():
			return false
		case <-time.After(200 * time.Millisecond):
		}
	}
}

func validProbeURL(raw string) bool {
	parsed, err := url.Parse(raw)
	return err == nil && len(raw) <= 2048 && parsed.Scheme == "https" && parsed.Hostname() != "" &&
		parsed.User == nil && parsed.RawQuery == "" && !parsed.ForceQuery && parsed.Fragment == "" && parsed.Opaque == ""
}

func httpsProbe(ctx context.Context, target string) bool {
	transport := &http.Transport{ForceAttemptHTTP2: true}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 30 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		return false
	}
	response, err := client.Do(request)
	if err != nil {
		return false
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return false
	}
	_, err = io.Copy(io.Discard, io.LimitReader(response.Body, 64*1024))
	return err == nil
}
