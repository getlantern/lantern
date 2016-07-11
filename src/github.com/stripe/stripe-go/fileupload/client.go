// Package fileupload provides the file upload related APIs
package fileupload

import (
	"bytes"
	"fmt"

	stripe "github.com/stripe/stripe-go"
)

const (
	DisputeEvidenceFile stripe.FileUploadPurpose = "dispute_evidence"
	IdentityDocFile     stripe.FileUploadPurpose = "identity_document"
)

// Client is used to invoke file upload APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs new file uploads.
// For more details see https://stripe.com/docs/api#create_file_upload.
func New(params *stripe.FileUploadParams) (*stripe.FileUpload, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.FileUploadParams) (*stripe.FileUpload, error) {
	if params == nil {
		return nil, fmt.Errorf("params cannot be nil, and params.Purpose and params.File must be set")
	}

	body := &bytes.Buffer{}
	boundary, err := params.AppendDetails(body)
	if err != nil {
		return nil, err
	}

	upload := &stripe.FileUpload{}
	err = c.B.CallMultipart("POST", "/files", c.Key, boundary, body, &params.Params, upload)

	return upload, err
}

// Get returns the details of a file upload.
// For more details see https://stripe.com/docs/api#retrieve_file_upload.
func Get(id string, params *stripe.FileUploadParams) (*stripe.FileUpload, error) {
	return getC().Get(id, params)

}

func (c Client) Get(id string, params *stripe.FileUploadParams) (*stripe.FileUpload, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params

		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	upload := &stripe.FileUpload{}
	err := c.B.Call("GET", "/files/"+id, c.Key, body, commonParams, upload)

	return upload, err
}

// List returns a list of file uploads.
// For more details see https://stripe.com/docs/api#list_file_uploads.
func List(params *stripe.FileUploadListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.FileUploadListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if len(params.Purpose) > 0 {
			body.Add("purpose", string(params.Purpose))
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.FileUploadList{}
		err := c.B.Call("GET", "/files", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of FileUploads.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// FileUpload returns the most recent FileUpload visited by a call to Next.
func (i *Iter) FileUpload() *stripe.FileUpload {
	return i.Current().(*stripe.FileUpload)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.UploadsBackend), stripe.Key}
}
