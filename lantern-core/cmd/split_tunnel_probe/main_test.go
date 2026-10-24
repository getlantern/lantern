package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestPublicIP(t *testing.T) {
	for _, test := range []struct {
		name   string
		status int
		body   string
		want   string
	}{
		{"ipv4", http.StatusOK, "192.0.2.1\n", "192.0.2.1"},
		{"error status", http.StatusServiceUnavailable, "192.0.2.1", ""},
		{"invalid body", http.StatusOK, "not an IP", ""},
		{"ipv6", http.StatusOK, "2001:db8::1", ""},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(test.status)
				_, _ = w.Write([]byte(test.body))
			}))
			defer server.Close()
			got, err := publicIP(context.Background(), server.URL)
			if got != test.want || (err != nil) != (test.want == "") {
				t.Fatalf("publicIP = %q, %v; want %q", got, err, test.want)
			}
		})
	}
}

func TestPublicIPCanceled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := publicIP(ctx, "http://127.0.0.1:1"); err == nil {
		t.Fatal("canceled request succeeded")
	}
}

func TestParseOptions(t *testing.T) {
	for _, args := range [][]string{{"--wait-for-input"}, {"extra"}, {"--unknown"}} {
		if _, err := parseOptions(args); err == nil {
			t.Errorf("parseOptions(%q) accepted invalid arguments", args)
		}
	}
	options, err := parseOptions([]string{"--json", "--wait-for-input", "--udp", "--stun-server", "127.0.0.1:3478"})
	if err != nil || !options.json || !options.wait || !options.udp || options.stun != "127.0.0.1:3478" {
		t.Fatalf("parseOptions = %+v, %v", options, err)
	}
}

func TestRunLegacyOutput(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, "192.0.2.1\n")
	}))
	defer server.Close()
	var output bytes.Buffer
	if err := run(context.Background(), []string{"--endpoint", server.URL}, strings.NewReader(""), &output, io.Discard); err != nil {
		t.Fatal(err)
	}
	if got := output.String(); got != "192.0.2.1\n" {
		t.Fatalf("output = %q", got)
	}
}

func TestRunConnectionHandshake(t *testing.T) {
	requested := make(chan struct{}, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requested <- struct{}{}
		_, _ = io.WriteString(w, "192.0.2.1")
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	input, resume := io.Pipe()
	defer input.Close()
	defer resume.Close()
	output, writer := io.Pipe()
	defer output.Close()
	done := make(chan error, 1)
	go func() {
		err := run(ctx, []string{"--json", "--wait-for-input", "--endpoint", server.URL}, input, writer, io.Discard)
		writer.CloseWithError(err)
		done <- err
	}()
	decoder := json.NewDecoder(output)
	var connected, result probeEvent
	if err := decoder.Decode(&connected); err != nil {
		t.Fatal(err)
	}
	if connected.Event != "connected" || connected.Protocol != "tcp" || connected.PID != os.Getpid() || !filepath.IsAbs(connected.Executable) {
		t.Fatalf("connected = %+v", connected)
	}
	if _, _, err := net.SplitHostPort(connected.LocalAddress); err != nil {
		t.Fatalf("local address: %v", err)
	}
	if connected.RemoteAddress != server.Listener.Addr().String() {
		t.Fatalf("remote address = %q", connected.RemoteAddress)
	}
	select {
	case <-requested:
		t.Fatal("HTTP request sent before ownership handshake")
	default:
	}
	if _, err := io.WriteString(resume, "\n"); err != nil {
		t.Fatal(err)
	}
	if err := decoder.Decode(&result); err != nil {
		t.Fatal(err)
	}
	if result.Event != "result" || result.PublicIP != "192.0.2.1" {
		t.Fatalf("result = %+v", result)
	}
	result.Event, result.PublicIP = "connected", ""
	if result != connected {
		t.Fatalf("socket evidence changed: %+v != %+v", result, connected)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

func TestWaitForInput(t *testing.T) {
	for _, input := range []string{"", "x"} {
		if err := waitForInput(context.Background(), strings.NewReader(input)); err == nil {
			t.Errorf("waitForInput(%q) succeeded", input)
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	input, writer := io.Pipe()
	defer input.Close()
	defer writer.Close()
	cancel()
	if err := waitForInput(ctx, input); err != context.Canceled {
		t.Fatalf("waitForInput = %v", err)
	}
}

func TestPublicIPRejectsRedirect(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/other", http.StatusFound)
	}))
	defer server.Close()
	if _, err := publicIP(context.Background(), server.URL); err == nil {
		t.Fatal("redirect accepted")
	}
}

func TestRunChildForwardsArgumentsAndInput(t *testing.T) {
	t.Setenv("SPLIT_TUNNEL_PROBE_TEST_CHILD", "1")
	var output bytes.Buffer
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	err := run(ctx, []string{"--child", os.Args[0], "-test.run=^TestProbeChildProcess$", "--", "--json", "--udp"}, strings.NewReader("\n"), &output, os.Stderr)
	if err != nil {
		t.Fatal(err)
	}
	var args []string
	if err := json.Unmarshal(output.Bytes(), &args); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(args, []string{"--json", "--udp", "\n"}) {
		t.Fatalf("child received %q", args)
	}
}

func TestProbeChildProcess(t *testing.T) {
	if os.Getenv("SPLIT_TUNNEL_PROBE_TEST_CHILD") != "1" {
		return
	}
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		os.Exit(1)
	}
	args := append(os.Args[len(os.Args)-2:], string(input))
	if json.NewEncoder(os.Stdout).Encode(args) != nil {
		os.Exit(1)
	}
	os.Exit(0)
}
