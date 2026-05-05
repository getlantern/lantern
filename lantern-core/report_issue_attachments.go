package lanterncore

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
	maxReportIssueAttachments     = 3
	maxReportIssueAttachmentBytes = 15 * 1024 * 1024
)

var allowedReportIssueAttachmentTypes = map[string]struct{}{
	"image/gif":  {},
	"image/jpeg": {},
	"image/png":  {},
}

type ReportIssueAttachment struct {
	Name      string `json:"name"`
	Path      string `json:"path"`
	MimeType  string `json:"mimeType"`
	SizeBytes int64  `json:"sizeBytes"`
}

func loadReportIssueAttachments(raw string) ([]*issue.Attachment, error) {
	attachments, err := parseReportIssueAttachments(raw)
	if err != nil {
		return nil, err
	}
	if len(attachments) == 0 {
		return nil, nil
	}

	prepared, err := validateReportIssueAttachmentMetadata(attachments)
	if err != nil {
		return nil, err
	}

	loaded := make([]*issue.Attachment, 0, len(prepared))
	for _, attachment := range prepared {
		loadedAttachment, err := buildReportIssueAttachment(attachment)
		if err != nil {
			return nil, err
		}
		loaded = append(loaded, loadedAttachment)
	}
	return loaded, nil
}

func parseReportIssueAttachments(raw string) ([]ReportIssueAttachment, error) {
	if strings.TrimSpace(raw) == "" {
		return nil, nil
	}

	var attachments []ReportIssueAttachment
	if err := json.Unmarshal([]byte(raw), &attachments); err != nil {
		return nil, fmt.Errorf("parse issue attachments: %w", err)
	}
	return attachments, nil
}

type preparedReportIssueAttachment struct {
	name     string
	path     string
	mimeType string
	size     int64
}

func validateReportIssueAttachmentMetadata(attachments []ReportIssueAttachment) ([]preparedReportIssueAttachment, error) {
	if len(attachments) > maxReportIssueAttachments {
		return nil, fmt.Errorf("too many attachments: max %d", maxReportIssueAttachments)
	}

	prepared := make([]preparedReportIssueAttachment, 0, len(attachments))
	var totalBytes int64
	for _, attachment := range attachments {
		item, err := prepareReportIssueAttachment(attachment)
		if err != nil {
			return nil, err
		}
		totalBytes += item.size
		if totalBytes > maxReportIssueAttachmentBytes {
			return nil, fmt.Errorf("attachments exceed %d bytes total", maxReportIssueAttachmentBytes)
		}
		prepared = append(prepared, item)
	}
	return prepared, nil
}

func prepareReportIssueAttachment(attachment ReportIssueAttachment) (preparedReportIssueAttachment, error) {
	name := sanitizeReportIssueAttachmentName(attachment.Name, attachment.Path)
	if name == "" {
		return preparedReportIssueAttachment{}, fmt.Errorf("attachment name is required")
	}

	path := strings.TrimSpace(attachment.Path)
	if path == "" {
		return preparedReportIssueAttachment{}, fmt.Errorf("attachment %q path is required", name)
	}
	if attachment.SizeBytes < 0 {
		return preparedReportIssueAttachment{}, fmt.Errorf("attachment %q size must be non-negative", name)
	}

	attachmentType := resolveDeclaredReportIssueAttachmentType(attachment.MimeType, name)
	if !isAllowedReportIssueAttachmentType(attachmentType) {
		return preparedReportIssueAttachment{}, fmt.Errorf("attachment %q type is not supported", name)
	}

	info, err := os.Stat(path)
	if err != nil {
		return preparedReportIssueAttachment{}, fmt.Errorf("stat attachment %q: %w", name, err)
	}
	if info.IsDir() {
		return preparedReportIssueAttachment{}, fmt.Errorf("attachment %q must be a file", name)
	}
	if info.Size() != attachment.SizeBytes {
		return preparedReportIssueAttachment{}, fmt.Errorf("attachment %q changed on disk before upload", name)
	}

	return preparedReportIssueAttachment{
		name:     name,
		path:     path,
		mimeType: attachmentType,
		size:     info.Size(),
	}, nil
}

func buildReportIssueAttachment(attachment preparedReportIssueAttachment) (*issue.Attachment, error) {
	data, err := readReportIssueAttachmentFile(attachment.path, attachment.size)
	if err != nil {
		return nil, fmt.Errorf("read attachment %q: %w", attachment.name, err)
	}
	attachmentType := canonicalReportIssueAttachmentType(
		parseMediaType(http.DetectContentType(data)),
	)
	if !isAllowedReportIssueAttachmentType(attachmentType) {
		return nil, fmt.Errorf("attachment %q content is not a supported image", attachment.name)
	}

	return &issue.Attachment{
		Name:       attachment.name,
		Type:       attachmentType,
		Data:       data,
		FirstClass: true,
	}, nil
}

func readReportIssueAttachmentFile(path string, expectedSize int64) ([]byte, error) {
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

func sanitizeReportIssueAttachmentName(name, path string) string {
	name = strings.TrimSpace(name)
	if name != "" {
		return filepath.Base(name)
	}
	return filepath.Base(strings.TrimSpace(path))
}

func resolveDeclaredReportIssueAttachmentType(mimeType, name string) string {
	if mediaType := parseMediaType(strings.TrimSpace(mimeType)); mediaType != "" {
		return canonicalReportIssueAttachmentType(mediaType)
	}
	return canonicalReportIssueAttachmentType(
		parseMediaType(mime.TypeByExtension(strings.ToLower(filepath.Ext(name)))),
	)
}

func canonicalReportIssueAttachmentType(mediaType string) string {
	if mediaType == "image/jpg" {
		return "image/jpeg"
	}
	return mediaType
}

func isAllowedReportIssueAttachmentType(mediaType string) bool {
	_, ok := allowedReportIssueAttachmentTypes[mediaType]
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
