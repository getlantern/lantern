// package cfl provides a utility for interacting with CloudFlare
package cfl

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"strings"
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
		return nil, fmt.Errorf("Error retrieving Cloudflare records: %v", err)
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

// Register ensures that a record with the given name and ip is registered and
// proxying (orange cloud enabled). An existing record can optionally be passed
// in, in which case the record is assumed to be registered and we enable the
// orange cloud for the existing record.
// EnsureRegistered returns:
//  - the record if registration was successful
//  - true of it was able to turn on proxying
//  - any error encountered
func (util *Util) EnsureRegistered(name string, ip string, rec *cloudflare.Record) (*cloudflare.Record, bool, error) {
	if rec == nil {
		// Register record
		var err error
		cr := cloudflare.CreateRecord{Type: "A", Name: name, Content: ip}
		rec, err = util.Client.CreateRecord(util.domain, &cr)

		if err != nil {
			if !isDuplicateRecord(err) {
				return nil, false, err
			}
			log.Debugf("%v (%v) already registered, looking up existing record", name, ip)
			// Note - this is pretty heavyweight since it fetches all
			// records, but this condition should rarely be hit anyway
			all, err := util.GetAllRecords()
			if err != nil {
				return nil, false, err
			}
			for _, r := range all {
				if r.Name == name && r.Value == ip {
					rec = &r
					break
				}
			}
			if rec == nil {
				return nil, false, fmt.Errorf("Unable to find existing record for %v (%v)!?", name, ip)
			}
		}
	}

	// Update the record to set the ServiceMode to 1 (orange cloud). For
	// whatever reason we can't do this on create.
	// Note for some reason CloudFlare seems to ignore the TTL here.
	ur := cloudflare.UpdateRecord{Type: "A", Name: name, Content: ip, Ttl: "360", ServiceMode: "1"}
	err := util.Client.UpdateRecord(util.domain, rec.Id, &ur)
	if err != nil {
		log.Debugf("Error updating record %v, destroying", rec)
		err2 := util.DestroyRecord(rec)
		if err2 != nil {
			log.Errorf("Unable to destroy incomplete record %v: %v", rec, err2)
			return rec, false, err
		}
		return nil, false, err
	}

	return rec, true, nil
}

func (util *Util) DestroyRecord(r *cloudflare.Record) error {
	return util.Client.DestroyRecord(util.domain, r.Id)
}

func isDuplicateRecord(err error) bool {
	return strings.Contains(err.Error(), "The record already exists.")
}
