package lanterncore

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

var testPNGData = []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n', 0x00}

func TestLoadReportIssueAttachmentsReturnsNilForEmptyInput(t *testing.T) {
	attachments, err := loadReportIssueAttachments("")
	if err != nil {
		t.Fatalf("loadReportIssueAttachments returned error: %v", err)
	}
	if attachments != nil {
		t.Fatalf("expected nil attachments for empty input, got %d", len(attachments))
	}
}

func TestBuildReportIssueAttachmentReadsAndMarksFirstClass(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	data := testPNGData
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	raw, err := json.Marshal([]ReportIssueAttachment{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: int64(len(data)),
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	attachments, err := loadReportIssueAttachments(string(raw))
	if err != nil {
		t.Fatalf("loadReportIssueAttachments returned error: %v", err)
	}
	if len(attachments) != 1 {
		t.Fatalf("expected 1 attachment, got %d", len(attachments))
	}
	attachment := attachments[0]
	if attachment.Name != "vpn_error.png" {
		t.Fatalf("unexpected attachment name: %q", attachment.Name)
	}
	if attachment.Type != "image/png" {
		t.Fatalf("unexpected attachment type: %q", attachment.Type)
	}
	if !attachment.FirstClass {
		t.Fatalf("expected attachment to be marked first class")
	}
	if string(attachment.Data) != string(data) {
		t.Fatalf("attachment data mismatch: got %q want %q", string(attachment.Data), string(data))
	}
}

func TestBuildReportIssueAttachmentRejectsChangedFiles(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	if err := os.WriteFile(path, testPNGData, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	_, err := validateReportIssueAttachmentMetadata([]ReportIssueAttachment{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: 999,
	}})
	if err == nil {
		t.Fatalf("expected size mismatch to fail")
	}
}

func TestBuildReportIssueAttachmentRejectsZeroSizeBypass(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	if err := os.WriteFile(path, testPNGData, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	_, err := validateReportIssueAttachmentMetadata([]ReportIssueAttachment{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: 0,
	}})
	if err == nil {
		t.Fatalf("expected missing exact size to fail")
	}
}

func TestLoadReportIssueAttachmentsEnforcesLimitsBeforeReading(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	if err := os.WriteFile(path, testPNGData, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	attachments := make([]ReportIssueAttachment, maxReportIssueAttachments+1)
	for i := range attachments {
		attachments[i] = ReportIssueAttachment{
			Name:      "vpn_error.png",
			Path:      path,
			MimeType:  "image/png",
			SizeBytes: int64(len(testPNGData)),
		}
	}
	raw, err := json.Marshal(attachments)
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	_, err = loadReportIssueAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "too many attachments") {
		t.Fatalf("expected too many attachments error, got %v", err)
	}
}

func TestLoadReportIssueAttachmentsRejectsTotalSizeOverLimit(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "huge.png")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatalf("create test attachment: %v", err)
	}
	if err := os.Truncate(path, maxReportIssueAttachmentBytes+1); err != nil {
		t.Fatalf("resize test attachment: %v", err)
	}

	raw, err := json.Marshal([]ReportIssueAttachment{{
		Name:      "huge.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: maxReportIssueAttachmentBytes + 1,
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	_, err = loadReportIssueAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "attachments exceed") {
		t.Fatalf("expected total size error, got %v", err)
	}
}

func TestLoadReportIssueAttachmentsRejectsUnsupportedTypes(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "notes.txt")
	if err := os.WriteFile(path, []byte("not an image"), 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	raw, err := json.Marshal([]ReportIssueAttachment{{
		Name:      "notes.txt",
		Path:      path,
		MimeType:  "text/plain",
		SizeBytes: int64(len("not an image")),
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	_, err = loadReportIssueAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "type is not supported") {
		t.Fatalf("expected unsupported type error, got %v", err)
	}
}

func TestLoadReportIssueAttachmentsRejectsMismatchedImageContent(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	data := []byte("not an image")
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	raw, err := json.Marshal([]ReportIssueAttachment{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: int64(len(data)),
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	_, err = loadReportIssueAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "content is not a supported image") {
		t.Fatalf("expected content type error, got %v", err)
	}
}
