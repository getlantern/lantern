package lanterncore

import (
	"encoding/json"
	"fmt"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/getlantern/radiance/issue"
)

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

	loaded := make([]*issue.Attachment, 0, len(attachments))
	for _, attachment := range attachments {
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

func buildReportIssueAttachment(attachment ReportIssueAttachment) (*issue.Attachment, error) {
	name := sanitizeReportIssueAttachmentName(attachment.Name, attachment.Path)
	if name == "" {
		return nil, fmt.Errorf("attachment name is required")
	}

	path := strings.TrimSpace(attachment.Path)
	if path == "" {
		return nil, fmt.Errorf("attachment %q path is required", name)
	}
	if attachment.SizeBytes < 0 {
		return nil, fmt.Errorf("attachment %q size must be non-negative", name)
	}

	info, err := os.Stat(path)
	if err != nil {
		return nil, fmt.Errorf("stat attachment %q: %w", name, err)
	}
	if info.IsDir() {
		return nil, fmt.Errorf("attachment %q must be a file", name)
	}
	if attachment.SizeBytes > 0 && info.Size() != attachment.SizeBytes {
		return nil, fmt.Errorf("attachment %q changed on disk before upload", name)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read attachment %q: %w", name, err)
	}

	return &issue.Attachment{
		Name:       name,
		Type:       resolveReportIssueAttachmentType(attachment.MimeType, name, data),
		Data:       data,
		FirstClass: true,
	}, nil
}

func sanitizeReportIssueAttachmentName(name, path string) string {
	name = strings.TrimSpace(name)
	if name != "" {
		return filepath.Base(name)
	}
	return filepath.Base(strings.TrimSpace(path))
}

func resolveReportIssueAttachmentType(mimeType, name string, data []byte) string {
	if mediaType := parseMediaType(strings.TrimSpace(mimeType)); mediaType != "" {
		return mediaType
	}

	if mediaType := parseMediaType(
		mime.TypeByExtension(strings.ToLower(filepath.Ext(name))),
	); mediaType != "" {
		return mediaType
	}

	if len(data) == 0 {
		return "application/octet-stream"
	}

	return parseMediaType(http.DetectContentType(data))
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
