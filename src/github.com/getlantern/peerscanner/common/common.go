package common

import (
	"log"

	"github.com/getlantern/cloudflare"
)

const (
	CF_DOMAIN     = "getiantem.org"
	MASQUERADE_AS = "cdnjs.com"
	ROOT_CA       = "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n"
	ROUNDROBIN    = "roundrobin"
	PEERS         = "peers"
	FALLBACKS     = "fallbacks"
)

type CloudFlareUtil struct {
	Client *cloudflare.Client
	Cached *cloudflare.RecordsResponse
}

func NewCloudFlareUtil() *CloudFlareUtil {
	client, err := cloudflare.NewClient("", "")
	if err != nil {
		log.Println("Could not create CloudFlare client:", err)
		return nil
	}
	cf := CloudFlareUtil{client, nil}
	return &cf
}

func (util *CloudFlareUtil) RemoveIpFromRoundRobin(ip string, subdomain string) error {
	roundrobin, err := util.GetRoundRobinRecords(subdomain)
	if err != nil {
		return err
	}
	return util.RemoveIpFromRoundRobinRecords(ip, roundrobin)

}

func (util *CloudFlareUtil) RemoveIpFromRoundRobinRecords(ip string, roundrobin []cloudflare.Record) error {
	for _, rec := range roundrobin {
		if rec.Value == ip {
			log.Println("Destroying record ", rec.Value)
			err := util.Client.DestroyRecord(rec.Domain, rec.Id)
			return err
		}
	}
	return nil
}

func (util *CloudFlareUtil) GetRoundRobinRecords(subdomain string) ([]cloudflare.Record, error) {
	records, err := util.GetAllRecords()

	if err != nil {
		log.Println("Could not get records:", err)
		return nil, err
	}

	recs := records.Response.Recs.Records

	roundrobin := make([]cloudflare.Record, 0)
	for _, record := range recs {
		if record.Name == subdomain {
			//log.Println("IN ROUNDROBIN IP: ", record.Name, record.Value)
			roundrobin = append(roundrobin, record)
		} else {
			//log.Println("NON ROUNDROBIN IP: ", record.Name, record.Value)
		}
	}
	return roundrobin, nil
}

func (util *CloudFlareUtil) GetAllRecords() (*cloudflare.RecordsResponse, error) {
	records, err := util.Client.LoadAll(CF_DOMAIN)
	if err != nil {
		log.Println("Error retrieving record!", err)
		return nil, err
	}
	//log.Println("Loaded original records...", records.Response.Recs.Count)

	if records.Response.Recs.HasMore {
		return util.getAllRecordsByIndex(records.Response.Recs.Count, records)
	}

	log.Println("Setting cached records")
	util.Cached = records
	return records, nil
}

func (util *CloudFlareUtil) getAllRecordsByIndex(index int, response *cloudflare.RecordsResponse) (*cloudflare.RecordsResponse, error) {
	records, err := util.Client.LoadAllAtIndex(CF_DOMAIN, index)
	if err != nil {
		log.Println("Error retrieving record!", err)
		return nil, err
	}

	//log.Println("Loaded original records...", records.Response.Recs.Count)

	response.Response.Recs.Records = append(response.Response.Recs.Records, records.Response.Recs.Records...)
	response.Response.Recs.Count = response.Response.Recs.Count + records.Response.Recs.Count

	if records.Response.Recs.HasMore {
		//log.Println("Adding additional records")
		return util.getAllRecordsByIndex(response.Response.Recs.Count, response)
	}

	log.Println("Setting total cached records")
	util.Cached = response
	return response, nil
}
