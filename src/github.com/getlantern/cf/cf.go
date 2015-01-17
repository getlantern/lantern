// package cf provides a utility for interacting with CloudFlare
package cf

import (
	"fmt"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("cf")
)

type Util struct {
	Client *cloudflare.Client
	Cached []cloudflare.Record
	domain string
}

func New(domain string, username string, apiKey string) (*Util, error) {
	client, err := cloudflare.NewClient(username, apiKey)
	if err != nil {
		return nil, fmt.Errorf("Unable to initialize client: %v", err)
	}
	return &Util{client, nil, domain}, nil
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
			err := util.Client.DestroyRecord(rec.Domain, rec.Id)
			return err
		}
	}
	return nil
}

func (util *Util) GetRotationRecords(subdomain string) ([]cloudflare.Record, error) {
	recs, err := util.GetAllRecords()
	if err != nil {
		return nil, fmt.Errorf("Could not get records:", err)
	}

	rotation := make([]cloudflare.Record, 0)
	for _, record := range recs {
		if record.Name == subdomain {
			log.Tracef("IN Rotation IP: %v - %v", record.Name, record.Value)
			rotation = append(rotation, record)
		} else {
			log.Tracef("NON Rotation IP:  %v - %v", record.Name, record.Value)
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

	log.Trace("Setting cached records")
	util.Cached = allRecords
	return allRecords, nil
}
