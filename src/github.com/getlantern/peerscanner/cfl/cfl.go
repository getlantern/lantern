// package cfl provides a utility for interacting with CloudFlare
package cfl

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"time"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("cfl")
)

type Util struct {
	Client *cloudflare.Client
	domain string
}

func New(domain string, username string, apiKey string) *Util {
	client := cloudflare.NewClient(username, apiKey)
	// Set a longish timeout on the HTTP client just in case
	client.Http = &http.Client{
		Timeout: 5 * time.Minute,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				ClientSessionCache: tls.NewLRUClientSessionCache(1000),
			},
		},
	}
	return &Util{client, domain}
}

func (util *Util) GetAllRecords() ([]cloudflare.Record, error) {
	resp, err := util.Client.LoadAll(util.domain)
	if err != nil {
		return nil, fmt.Errorf("Error retrieving records: %v", err)
	}

	allRecords := resp.Response.Recs.Records
	for resp.Response.Recs.HasMore {
		ix := len(allRecords)
		resp, err = util.Client.LoadAllAtIndex(util.domain, ix)
		if err != nil {
			return nil, fmt.Errorf("Error retrieving records at index %d: %v", ix, err)
		}
		allRecords = append(allRecords, resp.Response.Recs.Records...)
	}

	return allRecords, nil
}

func (util *Util) Register(name string, ip string, enableCdn bool) (*cloudflare.Record, error) {
	cr := cloudflare.CreateRecord{Type: "A", Name: name, Content: ip}
	rec, err := util.Client.CreateRecord(util.domain, &cr)

	if err != nil {
		return nil, err
	}

	if enableCdn {
		// Update the record to set the ServiceMode to 1 (orange cloud). For
		// whatever reason we can't do this on create.
		// Note for some reason CloudFlare seems to ignore the TTL here.
		ur := cloudflare.UpdateRecord{Type: "A", Name: name, Content: ip, Ttl: "360", ServiceMode: "1"}
		err = util.Client.UpdateRecord(util.domain, rec.Id, &ur)
		if err != nil {
			log.Tracef("Error updating record %v, destroying", rec)
			err2 := util.DestroyRecord(rec)
			if err2 != nil {
				log.Errorf("Unable to destroy incomplete record %v: %v", rec, err2)
			}
			return nil, err
		}
	}

	return rec, nil
}

func (util *Util) DestroyRecord(r *cloudflare.Record) error {
	return util.Client.DestroyRecord(util.domain, r.Id)
}
