package lanterncore

import (
	"os"
	"path/filepath"
	"testing"
)

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
	data := []byte("png-data")
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	attachment, err := buildReportIssueAttachment(ReportIssueAttachment{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: int64(len(data)),
	})
	if err != nil {
		t.Fatalf("buildReportIssueAttachment returned error: %v", err)
	}
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
	if err := os.WriteFile(path, []byte("png-data"), 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	_, err := buildReportIssueAttachment(ReportIssueAttachment{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: 999,
	})
	if err == nil {
		t.Fatalf("expected size mismatch to fail")
	}
}
