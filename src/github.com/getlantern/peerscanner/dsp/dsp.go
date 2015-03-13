package dsp

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"time"

	"github.com/getlantern/go-dnsimple/dnsimple"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("dnsimple")
)

type Util struct {
	Client *dnsimple.Client
	domain string
}

func New(domain string, email string, apiToken string) *Util {
	client := dnsimple.NewClient(apiToken, email)
	// Set a longish timeout on the HTTP client just in case
	client.HttpClient = &http.Client{
		Timeout: 5 * time.Minute,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				ClientSessionCache: tls.NewLRUClientSessionCache(1000),
			},
		},
	}
	return &Util{client, domain}
}

func (util *Util) GetAllRecords() ([]dnsimple.Record, error) {
	records, _, err := util.Client.Domains.ListRecords(util.domain, "", "A")
	if err != nil {
		return nil, fmt.Errorf("Error retrieving DNSimple records: %v", err)
	}
	return records, nil
}

func (util *Util) Register(name string, ip string) (*dnsimple.Record, error) {
	rec := dnsimple.Record{Name: name, Content: ip, Type: "A"}
	ret, _, err := util.Client.Domains.CreateRecord(util.domain, rec)
	return &ret, err
}

func (util *Util) DestroyRecord(r *dnsimple.Record) error {
	_, err := util.Client.Domains.DeleteRecord(util.domain, r.Id)
	return err
}
