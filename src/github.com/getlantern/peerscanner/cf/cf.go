// package cf provides a utility for interacting with CloudFlare
package cf

import (
	"crypto/tls"
	"fmt"
	"net/http"
	"time"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("cf")
)

type Util struct {
	Client *cloudflare.Client
	domain string
}

func New(domain string, username string, apiKey string) (*Util, error) {
	client, err := cloudflare.NewClient(username, apiKey)
	if err != nil {
		return nil, fmt.Errorf("Unable to initialize client: %v", err)
	}
	// Set a longish timeout on the HTTP client just in case
	client.Http.Timeout = 5 * time.Minute
	client.Http.Transport = &http.Transport{
		TLSClientConfig: &tls.Config{
			ClientSessionCache: tls.NewLRUClientSessionCache(1000),
		},
	}
	return &Util{client, domain}, nil
}

func (util *Util) DisableKeepAlives() {
	util.Client.Http.Transport = &http.Transport{
		DisableKeepAlives: true,
	}
}

func (util *Util) GetRotationRecords(subdomain string) ([]cloudflare.Record, error) {
	recs, err := util.GetAllRecords()
	if err != nil {
		return nil, fmt.Errorf("Could not get records:", err)
	}

	rotation := make([]cloudflare.Record, 0)
	for _, record := range recs {
		if record.Name == subdomain {
			rotation = append(rotation, record)
		}
	}
	return rotation, nil
}

func (util *Util) GetAllRecords() ([]cloudflare.Record, error) {
	resp, err := util.Client.LoadAll(util.domain)
	if err != nil {
		return nil, fmt.Errorf("Error retrieving records!", err)
	}

	allRecords := resp.Response.Recs.Records
	for resp.Response.Recs.HasMore {
		resp, err = util.Client.LoadAllAtIndex(util.domain, len(allRecords))
		if err != nil {
			return nil, fmt.Errorf("Error retrieving records at index!", err)
		}
		allRecords = append(allRecords, resp.Response.Recs.Records...)
	}

	return allRecords, nil
}

func (util *Util) Register(name string, ip string) (*cloudflare.Record, error) {
	cr := cloudflare.CreateRecord{Type: "A", Name: name, Content: ip}
	rec, err := util.Client.CreateRecord(util.domain, &cr)

	if err != nil {
		return nil, err
	}

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

	return rec, nil
}

func (util *Util) RemoveIpFromRotation(ip string, subdomain string) error {
	Rotation, err := util.GetRotationRecords(subdomain)
	if err != nil {
		return err
	}
	return util.RemoveIpFromRotationRecords(ip, Rotation)

}

func (util *Util) RemoveIpFromRotationRecords(ip string, Rotation []cloudflare.Record) error {
	for _, rec := range Rotation {
		if rec.Value == ip {
			log.Tracef("Destroying record: %v", rec.Value)
			err := util.DestroyRecord(&rec)
			return err
		}
	}
	return nil
}

func (util *Util) DestroyRecord(r *cloudflare.Record) error {
	return util.Client.DestroyRecord(util.domain, r.Id)
}
