package stripe

import (
	"encoding/json"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
)

// FileUploadParams is the set of parameters that can be used when creating a
// file upload.
// For more details see https://stripe.com/docs/api#create_file_upload.
type FileUploadParams struct {
	Params
	Purpose FileUploadPurpose
	File    *os.File
}

// FileUploadListParams is the set of parameters that can be used when listing
// file uploads. For more details see https://stripe.com/docs/api#list_file_uploads.
type FileUploadListParams struct {
	Purpose FileUploadPurpose
	ListParams
}

// FileUploadPurpose is the purpose of a particular file upload. Allowed values
// are "dispute_evidence" and "identity_document".
type FileUploadPurpose string

// FileUpload is the resource representing a Stripe file upload.
// For more details see https://stripe.com/docs/api#file_uploads.
type FileUpload struct {
	ID      string            `json:"id"`
	Created int64             `json:"created"`
	Size    int64             `json:"size"`
	Purpose FileUploadPurpose `json:"purpose"`
	URL     string            `json:"url"`
	Type    string            `json:"type"`
}

// FileUploadList is a list of file uploads as retrieved from a list endpoint.
type FileUploadList struct {
	ListMeta
	Values []*FileUpload `json:"data"`
}

// AppendDetails adds the file upload details to an io.ReadWriter. It returns
// the boundary string for a multipart/form-data request and an error (if one
// exists).
func (f *FileUploadParams) AppendDetails(body io.ReadWriter) (string, error) {
	writer := multipart.NewWriter(body)
	var err error

	if len(f.Purpose) > 0 {
		err = writer.WriteField("purpose", string(f.Purpose))
		if err != nil {
			return "", err
		}
	}

	if f.File != nil {
		part, err := writer.CreateFormFile("file", filepath.Base(f.File.Name()))
		if err != nil {
			return "", err
		}

		_, err = io.Copy(part, f.File)
		if err != nil {
			return "", err
		}
	}

	err = writer.Close()
	if err != nil {
		return "", err
	}

	return writer.Boundary(), nil
}

// UnmarshalJSON handles deserialization of a FileUpload.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (f *FileUpload) UnmarshalJSON(data []byte) error {
	type file FileUpload
	var ff file
	err := json.Unmarshal(data, &ff)
	if err == nil {
		*f = FileUpload(ff)
	} else {
		// the id is surrounded by "\" characters, so strip them
		f.ID = string(data[1 : len(data)-1])
	}

	return nil
}
