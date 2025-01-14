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
	"github.com/getlantern/lantern-outline/dialer"
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
	useRadiance := false
	dialer, err := createDialer(cfg, useRadiance)
	if err != nil {
		log.Fatal(err)
	}
	err = testConnect(ctx, cfg, dialer, args.URL)
	if err != nil {
		log.Fatal(err)
	}
}

func createDialer(cfg *config.Config, useRadiance bool) (transport.StreamDialer, error) {
	if useRadiance {
		return rtransport.DialerFrom(cfg)
	}
	return dialer.NewShadowsocks(cfg)
}

func testConnect(ctx context.Context, cfg *config.Config, streamDialer transport.StreamDialer, url string) error {

	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(cfg.CertPem)

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

	targetReq, err := backend.NewRequestWithHeaders(
		ctx,
		http.MethodGet,
		url,
		nil,
	)
	if err != nil {
		return err
	}

	targetReq.Header.Set(authTokenHeader, cfg.AuthToken)
	resp, err := httpClient.Do(targetReq)
	if err != nil {
		return err
	}

	defer resp.Body.Close()

	// Print the HTTP status
	fmt.Printf("Received HTTP Status: %s\n", resp.Status)

	// Optionally, read and print the response body
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
		return cfg
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
