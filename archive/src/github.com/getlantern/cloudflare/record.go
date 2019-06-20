package cloudflare

import (
	"errors"
	"fmt"
	"strconv"
)

type RecordsResponse struct {
	Response struct {
		Recs struct {
			Count   int      `json:"count"`
			HasMore bool     `json:"has_more"`
			Records []Record `json:"objs"`
		} `json:"recs"`
	} `json:"response"`
	Result  string `json:"result"`
	Message string `json:"msg"`
}

func (r *RecordsResponse) FindRecord(id string) (*Record, error) {
	if r.Result == "error" {
		return nil, fmt.Errorf("API Error: %s", r.Message)
	}

	objs := r.Response.Recs.Records
	notFoundErr := errors.New("Record not found")

	// No objects, return nil
	if len(objs) < 0 {
		return nil, notFoundErr
	}

	for _, v := range objs {
		// We have a match, return that
		if v.Id == id {
			return &v, nil
		}
	}

	return nil, notFoundErr
}

func (r *RecordsResponse) FindRecordByName(name string) (*Record, error) {
	if r.Result == "error" {
		return nil, fmt.Errorf("API Error: %s", r.Message)
	}

	objs := r.Response.Recs.Records
	notFoundErr := errors.New("Record not found")

	// No objects, return nil
	if len(objs) < 0 {
		return nil, notFoundErr
	}

	for _, v := range objs {
		// We have a match, return that
		if v.Name == name {
			return &v, nil
		}
	}

	return nil, notFoundErr
}

type RecordResponse struct {
	Response struct {
		Rec struct {
			Record Record `json:"obj"`
		} `json:"rec"`
	} `json:"response"`
	Result  string `json:"result"`
	Message string `json:"msg"`
}

func (r *RecordResponse) GetRecord() (*Record, error) {
	if r.Result == "error" {
		return nil, fmt.Errorf("API Error: %s", r.Message)
	}

	return &r.Response.Rec.Record, nil
}

// Record is used to represent a retrieved Record. All properties
// are set as strings.
type Record struct {
	Id       string `json:"rec_id"`
	Domain   string `json:"zone_name"`
	Name     string `json:"display_name"`
	FullName string `json:"name"`
	Value    string `json:"content"`
	Type     string `json:"type"`
	Priority string `json:"prio"`
	Ttl      string `json:"ttl"`
}

// CreateRecord contains the request parameters to create a new
// record.
type CreateRecord struct {
	Type     string
	Name     string
	Content  string
	Ttl      string
	Priority string
}

// CreateRecord creates a record from the parameters specified and
// returns an error if it fails. If no error and the name is returned,
// the Record was succesfully created.
func (c *Client) CreateRecord(domain string, opts *CreateRecord) (*Record, error) {
	// Make the request parameters
	params := make(map[string]string)
	params["z"] = domain

	params["type"] = opts.Type

	if opts.Name != "" {
		params["name"] = opts.Name
	}

	if opts.Content != "" {
		params["content"] = opts.Content
	}

	if opts.Priority != "" {
		params["prio"] = opts.Priority
	}

	if opts.Ttl != "" {
		params["ttl"] = opts.Ttl
	} else {
		params["ttl"] = "1"
	}

	req, err := c.NewRequest(params, "POST", "rec_new")
	if err != nil {
		return nil, err
	}

	resp, err := checkResp(c.Http.Do(req))
	if resp != nil && resp.Body != nil {
		defer func() {
			if err := resp.Body.Close(); err != nil {
				log.Debugf("Unable to close body of response: %v", err)
			}
		}()
	}
	if err != nil {
		return nil, fmt.Errorf("Error creating record: %s", err)
	}

	recordResp := new(RecordResponse)

	err = decodeBody(resp, &recordResp)

	if err != nil {
		return nil, fmt.Errorf("Error parsing record response: %s", err)
	}
	record, err := recordResp.GetRecord()
	if err != nil {
		return nil, err
	}

	// The request was successful
	return record, nil
}

// DestroyRecord destroys a record by the ID specified and
// returns an error if it fails. If no error is returned,
// the Record was succesfully destroyed.
func (c *Client) DestroyRecord(domain string, id string) error {
	params := make(map[string]string)

	params["z"] = domain
	params["id"] = id

	req, err := c.NewRequest(params, "POST", "rec_delete")
	if err != nil {
		return err
	}

	resp, err := checkResp(c.Http.Do(req))
	if resp != nil && resp.Body != nil {
		defer func() {
			if err := resp.Body.Close(); err != nil {
				log.Debugf("Unable to close response body: %v", err)
			}
		}()
	}
	if err != nil {
		return fmt.Errorf("Error deleting record: %s", err)
	}

	recordResp := new(RecordResponse)

	err = decodeBody(resp, &recordResp)

	if err != nil {
		return fmt.Errorf("Error parsing record response: %s", err)
	}
	_, err = recordResp.GetRecord()
	if err != nil {
		return err
	}

	// The request was successful
	return nil
}

// UpdateRecord contains the request parameters to update a
// record.
type UpdateRecord struct {
	Type        string
	Name        string
	Content     string
	Ttl         string
	Priority    string
	ServiceMode string
}

// UpdateRecord destroys a record by the ID specified and
// returns an error if it fails. If no error is returned,
// the Record was succesfully updated.
func (c *Client) UpdateRecord(domain string, id string, opts *UpdateRecord) error {
	params := make(map[string]string)
	params["z"] = domain
	params["id"] = id

	params["type"] = opts.Type

	if opts.Name != "" {
		params["name"] = opts.Name
	}

	if opts.Content != "" {
		params["content"] = opts.Content
	}

	if opts.Priority != "" {
		params["prio"] = opts.Priority
	}

	if opts.Ttl != "" {
		params["ttl"] = opts.Ttl
	}

	if opts.ServiceMode != "" {
		params["service_mode"] = opts.ServiceMode
	}

	req, err := c.NewRequest(params, "POST", "rec_edit")
	if err != nil {
		return err
	}

	resp, err := checkResp(c.Http.Do(req))
	if resp != nil && resp.Body != nil {
		defer func() {
			if err := resp.Body.Close(); err != nil {
				log.Debugf("Unable to close response body: %v", err)
			}
		}()
	}
	if err != nil {
		return fmt.Errorf("Error updating record: %s", err)
	}

	recordResp := new(RecordResponse)

	err = decodeBody(resp, &recordResp)

	if err != nil {
		return fmt.Errorf("Error parsing record response: %s", err)
	}
	_, err = recordResp.GetRecord()
	if err != nil {
		return err
	}

	// The request was successful
	return nil
}

// RetrieveRecord gets  a record by the ID specified and
// returns a Record and an error. An error will be returned for failed
// requests with a nil Record.
func (c *Client) RetrieveRecord(domain string, id string) (*Record, error) {
	records, err := c.LoadAll(domain)
	if err != nil {
		return nil, err
	}

	record, err := records.FindRecord(id)
	if err != nil {
		return nil, err
	}

	// The request was successful
	return record, nil
}

// RetrieveRecord gets  a record by the ID specified and
// returns a Record and an error. An error will be returned for failed
// requests with a nil Record.
func (c *Client) RetrieveRecordByName(domain string, name string) (*Record, error) {
	records, err := c.LoadAll(domain)
	if err != nil {
		return nil, err
	}

	record, err := records.FindRecordByName(name)
	if err != nil {
		return nil, err
	}

	// The request was successful
	return record, nil
}

func (c *Client) LoadAll(domain string) (*RecordsResponse, error) {
	params := make(map[string]string)
	// The zone we want
	params["z"] = domain
	return c.loadAll(&params)
}

func (c *Client) LoadAllAtIndex(domain string, index int) (*RecordsResponse, error) {
	params := make(map[string]string)
	// The zone we want
	params["z"] = domain
	params["o"] = strconv.Itoa(index)
	return c.loadAll(&params)
}

func (c *Client) loadAll(params *map[string]string) (*RecordsResponse, error) {
	req, err := c.NewRequest(*params, "GET", "rec_load_all")

	if err != nil {
		return nil, fmt.Errorf("Error creating request: %s", err)
	}

	resp, err := checkResp(c.Http.Do(req))
	if resp != nil && resp.Body != nil {
		defer func() {
			if err := resp.Body.Close(); err != nil {
				log.Debugf("Unable to close response body: %v", err)
			}
		}()
	}
	if err != nil {
		return nil, fmt.Errorf("Error loading all: %s", err)
	}

	records := new(RecordsResponse)

	err = decodeBody(resp, records)

	if err != nil {
		return nil, fmt.Errorf("Error decoding record response: %s", err)
	}

	// The request was successful
	return records, nil
}
