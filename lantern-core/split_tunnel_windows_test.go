//go:build windows && !novpn

package lanterncore

import (
	"context"
	"encoding/json"
	"io"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/getlantern/lantern/lantern-core/internal/processpath"
	"github.com/getlantern/radiance/vpn"
	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/common/process"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing-box/route/rule"
	"golang.org/x/sys/windows"
)

func TestSplitTunnelWindowsProcessLookup(t *testing.T) {
	path, short := splitTunnelProcessFixture(t)
	unrelated, _ := splitTunnelProcessFixture(t)
	type savedRule struct {
		name     string
		compiled adapter.HeadlessRule
		invert   bool
	}
	var rules []savedRule
	for _, configured := range []string{path, short, filepath.ToSlash(strings.ToUpper(short))} {
		for _, policy := range []vpn.SplitTunnelPolicy{vpn.SplitTunnelPolicyExclude, vpn.SplitTunnelPolicyInclude} {
			dir := t.TempDir()
			client := newSplitTunnelTestClient(t, dir)
			if err := client.handler.SetEnabled(true); err != nil {
				t.Fatal(err)
			}
			if err := client.handler.SetPolicy(policy); err != nil {
				t.Fatal(err)
			}
			paths := splitTunnelPaths{client: client}
			if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{configured}}, false); err != nil {
				t.Fatal(err)
			}
			saved := newSplitTunnelTestClient(t, dir).handler.Filters()
			if len(saved.ProcessPath) != 1 || saved.ProcessPath[0] != path || len(saved.ProcessPathRegex) != 1 {
				t.Fatalf("expected one canonical path and its alias rule, got %#v", saved)
			}
			data, err := os.ReadFile(filepath.Join(dir, "split-tunnel.json"))
			if err != nil {
				t.Fatal(err)
			}
			var stored option.PlainRuleSetCompat
			if err := json.Unmarshal(data, &stored); err != nil {
				t.Fatal(err)
			}
			if len(stored.Options.Rules) != 1 {
				t.Fatalf("expected one saved root rule, got %d", len(stored.Options.Rules))
			}
			compiled, err := rule.NewHeadlessRule(t.Context(), stored.Options.Rules[0])
			if err != nil {
				t.Fatal(err)
			}
			rules = append(rules, savedRule{configured, compiled, policy == vpn.SplitTunnelPolicyInclude})
		}
	}
	searcher, err := process.NewSearcher(process.Config{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = searcher.Close() })
	for _, network := range []string{"tcp", "udp"} {
		t.Run(network, func(t *testing.T) {
			for _, tc := range []struct {
				name, launch string
				match        bool
			}{
				{"long path", path, true},
				{"short path", short, true},
				{"long directory short filename", filepath.Join(filepath.Dir(path), filepath.Base(short)), true},
				{"short directory long filename", filepath.Join(filepath.Dir(short), filepath.Base(path)), true},
				{"same filename different directory", unrelated, false},
			} {
				t.Run(tc.name, func(t *testing.T) {
					source, destination, pid := splitTunnelProcessSocket(t, tc.launch, network)
					owner, err := searcher.FindProcessInfo(t.Context(), network, source, destination)
					if err != nil {
						t.Fatal(err)
					}
					if owner.ProcessID != uint32(pid) {
						t.Fatalf("process ID = %d, want child %d", owner.ProcessID, pid)
					}
					t.Logf("launched %q; Windows returned %q", tc.launch, owner.ProcessPath)
					for _, saved := range rules {
						if got := saved.compiled.Match(&adapter.InboundContext{ProcessInfo: owner}); got != (tc.match != saved.invert) {
							t.Errorf("rule for %q matched runtime path %q = %v, invert=%v", saved.name, owner.ProcessPath, got, saved.invert)
						}
					}
				})
			}
		})
	}
}

func TestSplitTunnelProcessHelper(t *testing.T) {
	network := os.Getenv("LANTERN_SPLIT_TUNNEL_PROCESS_HELPER")
	if network == "" {
		return
	}
	conn, err := net.DialTimeout(network+"4", os.Getenv("LANTERN_SPLIT_TUNNEL_PROCESS_ADDRESS"), 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if err := conn.SetWriteDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatal(err)
	}
	if _, err := conn.Write([]byte{1}); err != nil {
		t.Fatal(err)
	}
	// Keep the socket alive until the parent finishes looking up its owner.
	_, _ = io.Copy(io.Discard, os.Stdin)
}

// splitTunnelProcessFixture copies the test executable to a real long-path fixture.
func splitTunnelProcessFixture(t *testing.T) (string, string) {
	t.Helper()
	dir := filepath.Join(t.TempDir(), "Game Client 遊戲")
	if err := os.Mkdir(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	self, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	source, err := os.Open(self)
	if err != nil {
		t.Fatal(err)
	}
	defer source.Close()
	path := filepath.Join(dir, "Launcher Child Executable.exe")
	destination, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	_, copyErr := io.Copy(destination, source)
	closeErr := destination.Close()
	if copyErr != nil {
		t.Fatal(copyErr)
	}
	if closeErr != nil {
		t.Fatal(closeErr)
	}
	input, err := windows.UTF16PtrFromString(path)
	if err != nil {
		t.Fatal(err)
	}
	buffer := make([]uint16, windows.MAX_LONG_PATH)
	n, err := windows.GetShortPathName(input, &buffer[0], uint32(len(buffer)))
	if err != nil || n == 0 || n >= uint32(len(buffer)) {
		t.Fatalf("GetShortPathName: length=%d, error=%v", n, err)
	}
	short := windows.UTF16ToString(buffer[:n])
	if strings.EqualFold(filepath.Base(short), filepath.Base(path)) {
		if os.Getenv("LANTERN_REQUIRE_SHORT_PATH_TEST") == "1" {
			t.Fatal("8.3 aliases are disabled on the test volume")
		}
		t.Skip("8.3 aliases are disabled on this volume")
	}
	return processpath.Normalize(path), short
}

// splitTunnelProcessSocket launches the fixture and waits for its loopback traffic.
func splitTunnelProcessSocket(t *testing.T, path, network string) (netip.AddrPort, netip.AddrPort, int) {
	t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	var address net.Addr
	var receive func() (net.Addr, error)
	if network == "tcp" {
		listener, err := net.ListenTCP("tcp4", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = listener.Close() })
		if err := listener.SetDeadline(deadline); err != nil {
			t.Fatal(err)
		}
		address = listener.Addr()
		receive = func() (net.Addr, error) {
			conn, err := listener.AcceptTCP()
			if err != nil {
				return nil, err
			}
			t.Cleanup(func() { _ = conn.Close() })
			if err := conn.SetReadDeadline(deadline); err != nil {
				return nil, err
			}
			_, err = io.ReadFull(conn, make([]byte, 1))
			return conn.RemoteAddr(), err
		}
	} else {
		conn, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = conn.Close() })
		if err := conn.SetReadDeadline(deadline); err != nil {
			t.Fatal(err)
		}
		address = conn.LocalAddr()
		receive = func() (net.Addr, error) {
			_, remote, err := conn.ReadFromUDP(make([]byte, 1))
			return remote, err
		}
	}
	ctx, cancel := context.WithTimeout(t.Context(), 20*time.Second)
	t.Cleanup(cancel)
	child := exec.CommandContext(ctx, path, "-test.run=^TestSplitTunnelProcessHelper$")
	child.Env = append(os.Environ(), "LANTERN_SPLIT_TUNNEL_PROCESS_HELPER="+network,
		"LANTERN_SPLIT_TUNNEL_PROCESS_ADDRESS="+address.String())
	child.Stderr = os.Stderr
	child.Stdout = os.Stderr
	stdin, err := child.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = stdin.Close() })
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = stdin.Close()
		cancel()
		_ = child.Wait()
	})
	remote, err := receive()
	if err != nil {
		t.Fatal(err)
	}
	return netip.MustParseAddrPort(remote.String()), netip.MustParseAddrPort(address.String()), child.Process.Pid
}
