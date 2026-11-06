// split_tunnel_probe makes one HTTPS request from a known executable, optionally
// launched by a different executable. It is only used by the Windows smoke test.
package main

import (
	"context"
	"errors"
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
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if len(os.Args) == 3 && os.Args[1] == "--child" {
		child := exec.CommandContext(ctx, os.Args[2])
		child.Stdout, child.Stderr = os.Stdout, os.Stderr
		if child.Run() != nil {
			fmt.Fprintln(os.Stderr, "child probe failed")
			os.Exit(1)
		}
		return
	}
	if len(os.Args) != 1 {
		fmt.Fprintln(os.Stderr, "invalid probe arguments")
		os.Exit(1)
	}
	ip, err := publicIP(ctx, "https://api4.ipify.org")
	if err != nil {
		fmt.Fprintln(os.Stderr, "public IP probe failed")
		os.Exit(1)
	}
	fmt.Println(ip)
}

// publicIP avoids proxy environment variables and uses IPv4 for a consistent
// comparison between direct and tunneled connections.
func publicIP(ctx context.Context, endpoint string) (string, error) {
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, address string) (net.Conn, error) {
			return dialer.DialContext(ctx, "tcp4", address)
		},
		TLSHandshakeTimeout: 5 * time.Second,
		DisableKeepAlives:   true,
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 10 * time.Second}
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
