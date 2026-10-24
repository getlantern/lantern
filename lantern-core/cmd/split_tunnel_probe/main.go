// split_tunnel_probe measures TCP or UDP routing from a known executable.
// It is only used by the Windows smoke test.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := run(ctx, os.Args[1:], os.Stdin, os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

type probeOptions struct {
	json, wait, udp bool
	endpoint, stun  string
}

type probeEvent struct {
	Event         string `json:"event"`
	Executable    string `json:"executable"`
	PID           int    `json:"pid"`
	Protocol      string `json:"protocol"`
	LocalAddress  string `json:"localAddress"`
	RemoteAddress string `json:"remoteAddress"`
	PublicIP      string `json:"publicIP,omitempty"`
}

// parseOptions keeps the legacy one-line output unless JSON is requested.
func parseOptions(args []string) (probeOptions, error) {
	var options probeOptions
	flags := flag.NewFlagSet("split_tunnel_probe", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	flags.BoolVar(&options.json, "json", false, "emit connection and result JSON lines")
	flags.BoolVar(&options.wait, "wait-for-input", false, "wait for a newline after reporting the socket")
	flags.BoolVar(&options.udp, "udp", false, "send a STUN binding request over UDP")
	flags.StringVar(&options.endpoint, "endpoint", "https://api4.ipify.org", "TCP public IP endpoint")
	// Cloudflare documents this public endpoint at developers.cloudflare.com/realtime/turn/.
	flags.StringVar(&options.stun, "stun-server", "stun.cloudflare.com:3478", "UDP STUN endpoint")
	if err := flags.Parse(args); err != nil {
		return options, err
	}
	if flags.NArg() != 0 || (options.wait && !options.json) {
		return options, errors.New("invalid probe arguments: --wait-for-input requires --json")
	}
	return options, nil
}

// run forwards launcher input to the child so the test can inspect its live socket.
func run(ctx context.Context, args []string, input io.Reader, output, stderr io.Writer) error {
	if len(args) != 0 && args[0] == "--child" {
		if len(args) < 2 || args[1] == "" {
			return errors.New("--child requires an executable")
		}
		child := exec.CommandContext(ctx, args[1], args[2:]...)
		child.Stdin, child.Stdout, child.Stderr = input, output, stderr
		return child.Run()
	}
	options, err := parseOptions(args)
	if err != nil {
		return err
	}
	executable, err := os.Executable()
	if err != nil {
		return err
	}
	event := probeEvent{Event: "connected", Executable: executable, PID: os.Getpid(), Protocol: "tcp"}
	if options.udp {
		event.Protocol = "udp"
	}
	encoder := json.NewEncoder(output)
	connected := func(conn net.Conn) error {
		event.LocalAddress, event.RemoteAddress = conn.LocalAddr().String(), conn.RemoteAddr().String()
		if options.json {
			if err := encoder.Encode(event); err != nil {
				return err
			}
		}
		if options.wait {
			return waitForInput(ctx, input)
		}
		return nil
	}
	var ip string
	if options.udp {
		ip, err = udpPublicIP(ctx, options.stun, connected)
	} else {
		ip, err = tcpPublicIP(ctx, options.endpoint, connected)
	}
	if err != nil {
		return fmt.Errorf("%s public IP probe: %w", event.Protocol, err)
	}
	if options.json {
		event.Event, event.PublicIP = "result", ip
		return encoder.Encode(event)
	}
	_, err = fmt.Fprintln(output, ip)
	return err
}

// waitForInput bounds the pause used by CI to verify socket ownership in Windows.
func waitForInput(ctx context.Context, input io.Reader) error {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	ready := make(chan error, 1)
	go func() {
		var buffer [1]byte
		_, err := io.ReadFull(input, buffer[:])
		if err == nil && buffer[0] != '\n' {
			err = errors.New("expected a newline to resume the probe")
		}
		ready <- err
	}()
	select {
	case err := <-ready:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

// publicIP avoids proxy environment variables and uses IPv4 for a consistent
// comparison between direct and tunneled connections.
func publicIP(ctx context.Context, endpoint string) (string, error) {
	return tcpPublicIP(ctx, endpoint, nil)
}

// tcpPublicIP reports the socket before TLS or HTTP can finish the connection.
func tcpPublicIP(ctx context.Context, endpoint string, connected func(net.Conn) error) (string, error) {
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, address string) (net.Conn, error) {
			conn, err := dialer.DialContext(ctx, "tcp4", address)
			if err == nil && connected != nil {
				if err = connected(conn); err != nil {
					conn.Close()
					return nil, err
				}
			}
			return conn, err
		},
		TLSHandshakeTimeout: 5 * time.Second,
		DisableKeepAlives:   true,
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{
		Transport: transport,
		Timeout:   25 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return errors.New("probe endpoint redirected")
		},
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return "", err
	}
	response, err := client.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", errors.New("unexpected probe status")
	}
	body, err := io.ReadAll(io.LimitReader(response.Body, 64))
	if err != nil {
		return "", err
	}
	ip := strings.TrimSpace(string(body))
	if net.ParseIP(ip).To4() == nil {
		return "", errors.New("invalid probe IP")
	}
	return ip, nil
}
