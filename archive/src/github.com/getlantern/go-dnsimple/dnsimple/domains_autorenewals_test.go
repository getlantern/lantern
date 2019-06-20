package dnsimple

import (
	"net/http"
	"testing"
)

func TestDomainsService_EnableAutoRenewal(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/auto_renewal", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "POST")
	})

	_, err := client.Domains.EnableAutoRenewal("example.com")

	if err != nil {
		t.Errorf("Domains.EnableAutoRenewal returned %v", err)
	}
}

func TestDomainsService_DisableAutoRenewal(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/auto_renewal", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "DELETE")
	})

	_, err := client.Domains.DisableAutoRenewal("example.com")

	if err != nil {
		t.Errorf("Domains.DisableAutoRenewal returned %v", err)
	}
}

func TestDomainsService_SetAutoRenewal_enable(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/auto_renewal", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "POST")
	})

	_, err := client.Domains.SetAutoRenewal("example.com", true)

	if err != nil {
		t.Errorf("Domains.SetAutoRenewal (enable) returned %v", err)
	}
}

func TestDomainsService_SetAutoRenewal_disable(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/auto_renewal", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "DELETE")
	})

	_, err := client.Domains.SetAutoRenewal("example.com", false)

	if err != nil {
		t.Errorf("Domains.SetAutoRenewal (disable) returned %v", err)
	}
}
