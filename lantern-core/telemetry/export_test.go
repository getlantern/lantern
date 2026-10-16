//go:build linux

package telemetry_test

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/getlantern/common"
	"github.com/getlantern/radiance/config"
	"github.com/getlantern/radiance/telemetry"
	"go.opentelemetry.io/otel"
	metricpb "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	tracepb "go.opentelemetry.io/proto/otlp/collector/trace/v1"
	resourcepb "go.opentelemetry.io/proto/otlp/resource/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/metadata"
)

const (
	smokeDeviceID = "synthetic-telemetry-smoke-device"
	smokeHeader   = "x-lantern-telemetry-smoke"
	smokeValue    = "synthetic-ci"
	smokeScope    = "lantern.telemetry.smoke"
	smokeSpan     = "lantern.telemetry.smoke.span"
	smokeCounter  = "lantern.telemetry.smoke.counter"
)

type traceCollector struct {
	tracepb.UnimplementedTraceServiceServer
	requests chan *tracepb.ExportTraceServiceRequest
}

func (c *traceCollector) Export(ctx context.Context, request *tracepb.ExportTraceServiceRequest) (*tracepb.ExportTraceServiceResponse, error) {
	select {
	case c.requests <- request:
		return &tracepb.ExportTraceServiceResponse{}, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

type metricCollector struct {
	metricpb.UnimplementedMetricsServiceServer
	requests chan *metricpb.ExportMetricsServiceRequest
}

func (c *metricCollector) Export(ctx context.Context, request *metricpb.ExportMetricsServiceRequest) (*metricpb.ExportMetricsServiceResponse, error) {
	select {
	case c.requests <- request:
		return &metricpb.ExportMetricsServiceResponse{}, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func TestRadianceTelemetryExportsOverTLS(t *testing.T) {
	certificate := collectorCertificate(t)
	t.Setenv("RADIANCE_ENV", "dev")
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	server := grpc.NewServer(
		grpc.Creds(credentials.NewTLS(&tls.Config{
			Certificates: []tls.Certificate{certificate},
			MinVersion:   tls.VersionTLS12,
		})),
		grpc.UnaryInterceptor(func(ctx context.Context, request any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
			if got := metadata.ValueFromIncomingContext(ctx, smokeHeader); len(got) != 1 || got[0] != smokeValue {
				t.Errorf("collector header = %q, want %q", got, smokeValue)
			}
			return handler(ctx, request)
		}),
	)
	traces := &traceCollector{requests: make(chan *tracepb.ExportTraceServiceRequest, 1)}
	metrics := &metricCollector{requests: make(chan *metricpb.ExportMetricsServiceRequest, 1)}
	tracepb.RegisterTraceServiceServer(server, traces)
	metricpb.RegisterMetricsServiceServer(server, metrics)
	served := make(chan error, 1)
	go func() { served <- server.Serve(listener) }()
	t.Cleanup(func() {
		server.Stop()
		if err := <-served; err != nil && !errors.Is(err, grpc.ErrServerStopped) {
			t.Errorf("collector stopped: %v", err)
		}
	})
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := telemetry.CloseContext(ctx); err != nil {
			t.Errorf("cleanup telemetry: %v", err)
		}
	})
	if err := telemetry.Initialize(smokeDeviceID, config.Config{
		Country:  "ZZ",
		Features: map[string]bool{common.TRACES: true, common.METRICS: true},
		OTEL: common.OTEL{
			Endpoint:         listener.Addr().String(),
			Headers:          map[string]string{smokeHeader: smokeValue},
			TracesSampleRate: 1,
			MetricsInterval:  3600,
		},
	}, false); err != nil {
		t.Fatal(err)
	}
	ctx, span := otel.Tracer(smokeScope).Start(t.Context(), smokeSpan)
	span.End()
	counter, err := otel.Meter(smokeScope).Int64Counter(smokeCounter)
	if err != nil {
		t.Fatal(err)
	}
	counter.Add(ctx, 7)
	flushCtx, cancel := context.WithTimeout(t.Context(), 20*time.Second)
	defer cancel()
	if err := telemetry.CloseContext(flushCtx); err != nil {
		t.Fatalf("flush telemetry: %v", err)
	}
	select {
	case request := <-traces.requests:
		found := false
		for _, batch := range request.ResourceSpans {
			for _, scope := range batch.ScopeSpans {
				for _, span := range scope.Spans {
					if span.Name == smokeSpan {
						found = true
						assertResource(t, batch.Resource)
						if scope.Scope.GetName() != smokeScope {
							t.Errorf("trace scope = %q", scope.Scope.GetName())
						}
					}
				}
			}
		}
		if !found {
			t.Fatal("collector did not receive the smoke span")
		}
	case <-flushCtx.Done():
		t.Fatal("collector did not receive traces before the shutdown deadline")
	}
	select {
	case request := <-metrics.requests:
		found := false
		for _, batch := range request.ResourceMetrics {
			for _, scope := range batch.ScopeMetrics {
				for _, metric := range scope.Metrics {
					if metric.Name != smokeCounter {
						continue
					}
					found = true
					assertResource(t, batch.Resource)
					points := metric.GetSum().GetDataPoints()
					if len(points) != 1 || points[0].GetAsInt() != 7 {
						t.Errorf("counter points = %v, want one integer value of 7", points)
					}
				}
			}
		}
		if !found {
			t.Fatal("collector did not receive the smoke counter")
		}
	case <-flushCtx.Done():
		t.Fatal("collector did not receive metrics before the shutdown deadline")
	}
}

func assertResource(t *testing.T, resource *resourcepb.Resource) {
	t.Helper()
	want := map[string]string{
		"service.name":                "radiance",
		"client.device_id":            smokeDeviceID,
		"deployment.environment.name": "dev",
	}
	for _, attribute := range resource.GetAttributes() {
		if value, ok := want[attribute.Key]; ok {
			if got := attribute.Value.GetStringValue(); got != value {
				t.Errorf("resource %s = %q, want %q", attribute.Key, got, value)
			}
			delete(want, attribute.Key)
		}
	}
	for key := range want {
		t.Errorf("collector resource is missing %s", key)
	}
}

func collectorCertificate(t *testing.T) tls.Certificate {
	t.Helper()
	caKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	ca := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "Lantern telemetry smoke CA"},
		NotBefore:             now.Add(-time.Minute),
		NotAfter:              now.Add(time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign,
	}
	caDER, err := x509.CreateCertificate(rand.Reader, ca, ca, &caKey.PublicKey, caKey)
	if err != nil {
		t.Fatal(err)
	}
	caFile := filepath.Join(t.TempDir(), "collector-ca.pem")
	if err := os.WriteFile(caFile, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: caDER}), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("SSL_CERT_FILE", caFile)
	t.Setenv("SSL_CERT_DIR", t.TempDir())
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	leaf := &x509.Certificate{
		SerialNumber: big.NewInt(2),
		NotBefore:    ca.NotBefore,
		NotAfter:     ca.NotAfter,
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
		KeyUsage:     x509.KeyUsageDigitalSignature,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	der, err := x509.CreateCertificate(rand.Reader, leaf, ca, &key.PublicKey, caKey)
	if err != nil {
		t.Fatal(err)
	}
	return tls.Certificate{Certificate: [][]byte{der}, PrivateKey: key}
}
