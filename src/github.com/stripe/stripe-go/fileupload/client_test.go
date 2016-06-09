package fileupload

import (
	"os"
	"testing"

	stripe "github.com/stripe/stripe-go"
	. "github.com/stripe/stripe-go/utils"
)

const (
	expectedSize = 734
	expectedType = "pdf"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestFileUploadNewThenGet(t *testing.T) {
	f, err := os.Open("test_data.pdf")
	if err != nil {
		t.Errorf("Unable to open test file upload file %v\n", err)
	}

	uploadParams := &stripe.FileUploadParams{
		Purpose: "dispute_evidence",
		File:    f,
	}

	target, err := New(uploadParams)
	if err != nil {
		t.Error(err)
	}

	if target.Size != expectedSize {
		t.Errorf("(POST) Size %v does not match expected size %v\n", target.Size, expectedSize)
	}

	if target.Purpose != uploadParams.Purpose {
		t.Errorf("(POST) Purpose %v does not match expected purpose %v\n", target.Purpose, uploadParams.Purpose)
	}

	if target.Type != expectedType {
		t.Errorf("(POST) Type %v does not match expected type %v\n", target.Type, expectedType)
	}

	res, err := Get(target.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != res.ID {
		t.Errorf("(GET) File upload id %q does not match expected id %q\n", target.ID, res.ID)
	}
}

func TestFileUploadList(t *testing.T) {
	f, err := os.Open("test_data.pdf")
	if err != nil {
		t.Errorf("Unable to open test file upload file %v\n", err)
	}

	uploadParams := &stripe.FileUploadParams{
		Purpose: "dispute_evidence",
		File:    f,
	}

	_, err = New(uploadParams)
	if err != nil {
		t.Error(err)
	}

	params := &stripe.FileUploadListParams{}
	params.Filters.AddFilter("limit", "", "5")
	params.Single = true

	i := List(params)
	for i.Next() {
		if i.FileUpload() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}

	if err := i.Err(); err != nil {
		t.Error(err)
	}
}
