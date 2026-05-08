package reportissue

import (
	"encoding/json"
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/getlantern/radiance/issue"
)

const (
	maxAttachments     = 3
	maxAttachmentBytes = 15 * 1024 * 1024
)

var allowedAttachmentTypes = map[string]struct{}{
	"image/gif":  {},
	"image/jpeg": {},
	"image/png":  {},
}

type AttachmentMetadata struct {
	Name      string `json:"name"`
	Path      string `json:"path"`
	MimeType  string `json:"mimeType"`
	SizeBytes int64  `json:"sizeBytes"`
}

// LoadAttachments decodes, validates, and reads screenshot attachments for issue reports.
func LoadAttachments(raw string) ([]*issue.Attachment, error) {
	attachments, err := parseAttachments(raw)
	if err != nil {
		return nil, err
	}
	if len(attachments) == 0 {
		return nil, nil
	}

	prepared, err := validateMetadata(attachments)
	if err != nil {
		return nil, err
	}

	loaded := make([]*issue.Attachment, 0, len(prepared))
	for _, attachment := range prepared {
		loadedAttachment, err := buildAttachment(attachment)
		if err != nil {
			return nil, err
		}
		loaded = append(loaded, loadedAttachment)
	}
	return loaded, nil
}

func parseAttachments(raw string) ([]AttachmentMetadata, error) {
	if strings.TrimSpace(raw) == "" {
		return nil, nil
	}

	var attachments []AttachmentMetadata
	if err := json.Unmarshal([]byte(raw), &attachments); err != nil {
		return nil, fmt.Errorf("parse issue attachments: %w", err)
	}
	return attachments, nil
}

type preparedAttachment struct {
	name     string
	path     string
	mimeType string
	size     int64
}

func validateMetadata(attachments []AttachmentMetadata) ([]preparedAttachment, error) {
	if len(attachments) > maxAttachments {
		return nil, fmt.Errorf("too many attachments: max %d", maxAttachments)
	}

	prepared := make([]preparedAttachment, 0, len(attachments))
	var totalBytes int64
	for _, attachment := range attachments {
		item, err := prepareAttachment(attachment)
		if err != nil {
			return nil, err
		}
		totalBytes += item.size
		if totalBytes > maxAttachmentBytes {
			return nil, fmt.Errorf("attachments exceed %d bytes total", maxAttachmentBytes)
		}
		prepared = append(prepared, item)
	}
	return prepared, nil
}

func prepareAttachment(attachment AttachmentMetadata) (preparedAttachment, error) {
	name := sanitizeAttachmentName(attachment.Name, attachment.Path)
	if name == "" {
		return preparedAttachment{}, fmt.Errorf("attachment name is required")
	}

	path := strings.TrimSpace(attachment.Path)
	if path == "" {
		return preparedAttachment{}, fmt.Errorf("attachment %q path is required", name)
	}
	if attachment.SizeBytes < 0 {
		return preparedAttachment{}, fmt.Errorf("attachment %q size must be non-negative", name)
	}

	attachmentType := resolveDeclaredAttachmentType(attachment.MimeType, name)
	if !isAllowedAttachmentType(attachmentType) {
		return preparedAttachment{}, fmt.Errorf("attachment %q type is not supported", name)
	}

	info, err := os.Stat(path)
	if err != nil {
		return preparedAttachment{}, fmt.Errorf("stat attachment %q: %w", name, err)
	}
	if info.IsDir() {
		return preparedAttachment{}, fmt.Errorf("attachment %q must be a file", name)
	}
	if info.Size() != attachment.SizeBytes {
		return preparedAttachment{}, fmt.Errorf("attachment %q changed on disk before upload", name)
	}

	return preparedAttachment{
		name:     name,
		path:     path,
		mimeType: attachmentType,
		size:     info.Size(),
	}, nil
}

func buildAttachment(attachment preparedAttachment) (*issue.Attachment, error) {
	data, err := readAttachmentFile(attachment.path, attachment.size)
	if err != nil {
		return nil, fmt.Errorf("read attachment %q: %w", attachment.name, err)
	}
	attachmentType := canonicalAttachmentType(
		parseMediaType(http.DetectContentType(data)),
	)
	if !isAllowedAttachmentType(attachmentType) {
		return nil, fmt.Errorf("attachment %q content is not a supported image", attachment.name)
	}

	return &issue.Attachment{
		Name: attachment.name,
		Type: attachmentType,
		Data: data,
	}, nil
}

func readAttachmentFile(path string, expectedSize int64) ([]byte, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	data, err := io.ReadAll(io.LimitReader(file, expectedSize+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) != expectedSize {
		return nil, fmt.Errorf("file size changed during read")
	}
	return data, nil
}

func sanitizeAttachmentName(name, path string) string {
	name = strings.TrimSpace(name)
	if name != "" {
		return filepath.Base(name)
	}
	return filepath.Base(strings.TrimSpace(path))
}

func resolveDeclaredAttachmentType(mimeType, name string) string {
	if mediaType := parseMediaType(strings.TrimSpace(mimeType)); mediaType != "" {
		return canonicalAttachmentType(mediaType)
	}
	return canonicalAttachmentType(
		parseMediaType(mime.TypeByExtension(strings.ToLower(filepath.Ext(name)))),
	)
}

func canonicalAttachmentType(mediaType string) string {
	if mediaType == "image/jpg" {
		return "image/jpeg"
	}
	return mediaType
}

func isAllowedAttachmentType(mediaType string) bool {
	_, ok := allowedAttachmentTypes[mediaType]
	return ok
}

func parseMediaType(value string) string {
	if value == "" {
		return ""
	}

	mediaType, _, err := mime.ParseMediaType(strings.ToLower(value))
	if err == nil {
		return mediaType
	}
	return strings.ToLower(value)
}
