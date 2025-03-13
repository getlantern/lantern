// conncheck is a simple utility that checks connectivity to proxies returned by Radiance
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/Jigsaw-Code/outline-sdk/transport"
	"github.com/alexflint/go-arg"
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/dialer"
	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/config"
	rtransport "github.com/getlantern/radiance/transport"
	"google.golang.org/protobuf/encoding/protojson"
)

const (
	configPollInterval = 5 * time.Second
	authTokenHeader    = "X-Lantern-Auth-Token"
)

var (
	log = golog.LoggerFor("conncheck")
)

type Args struct {
	URL        string `arg:"--url,required" help:"The URL to test connectivity against"`
	ConfigPath string `arg:"--config" help:"Path to the local configuration file"`
	Radiance   bool   `arg:"--radiance" help:"Whether or not to test with radiance"`
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	// Parse command-line arguments
	var args Args
	if err := arg.Parse(&args); err != nil {
		log.Fatal(err)
	}

	cfg := loadConfig(ctx, args.ConfigPath)
	fmt.Printf("Loaded config from %s\n", args.ConfigPath)
	dialer, err := createDialer(cfg, args.Radiance)
	if err != nil {
		log.Fatal(err)
	}
	err = testConnect(ctx, cfg, dialer, args.URL)
	if err != nil {
		log.Fatal(err)
	}
}

// createDialer creates a transport.StreamDialer based on the provided configuration.
func createDialer(cfg *config.Config, useRadiance bool) (transport.StreamDialer, error) {
	if useRadiance {
		return rtransport.DialerFrom(cfg)
	}
	return dialer.NewDialer(cfg)
}

// testConnect tests connectivity by making an HTTP GET request to the specified URL.
func testConnect(ctx context.Context, cfg *config.Config, streamDialer transport.StreamDialer, url string) error {

	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(cfg.CertPem)

	// Set up an HTTP client with custom transport that uses the StreamDialer for connections.
	httpClient := http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				RootCAs:            caCertPool,
				InsecureSkipVerify: true,
				ServerName:         cfg.Addr,
			},
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				return streamDialer.DialStream(ctx, addr)
			},
		},
	}

	// Create the HTTP GET request to the target URL.
	targetReq, err := backend.NewRequestWithHeaders(
		ctx,
		http.MethodGet,
		url,
		nil,
	)
	if err != nil {
		return err
	}
	// Add the authentication token to the request headers.
	targetReq.Header.Set(authTokenHeader, cfg.AuthToken)

	resp, err := httpClient.Do(targetReq)
	if err != nil {
		return err
	}

	defer resp.Body.Close()

	// Print the HTTP status
	fmt.Printf("Received HTTP Status: %s\n", resp.Status)

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response body: %v", err)
	}
	fmt.Printf("Response Body:\n%s\n", string(body))
	return nil
}

// Load configuration file
func loadConfig(ctx context.Context, configPath string) *config.Config {
	if configPath == "" {
		confHandler := config.NewConfigHandler(2 * time.Second)
		cfg, err := confHandler.GetConfig(ctx)
		if err != nil {
			log.Fatal(err)
		}
		if len(cfg) == 0 {
			log.Fatal("Configuration is empty")
		}
		return cfg[0]
	}
	var cfg config.Config
	b, err := os.ReadFile(configPath)
	if err != nil {
		log.Fatalf("Failed to read config file at %s: %v", configPath, err)
	}
	err = protojson.Unmarshal(b, &cfg)
	if err != nil {
		log.Fatal(err)
	}
	return &cfg
}
