package reportissue

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

var testPNGData = []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n', 0x00}

func TestLoadAttachmentsReturnsNilForEmptyInput(t *testing.T) {
	attachments, err := LoadAttachments("")
	if err != nil {
		t.Fatalf("LoadAttachments returned error: %v", err)
	}
	if attachments != nil {
		t.Fatalf("expected nil attachments for empty input, got %d", len(attachments))
	}
}

func TestBuildAttachmentReadsImageData(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	data := testPNGData
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	raw, err := json.Marshal([]AttachmentMetadata{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: int64(len(data)),
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	attachments, err := LoadAttachments(string(raw))
	if err != nil {
		t.Fatalf("LoadAttachments returned error: %v", err)
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
	if string(attachment.Data) != string(data) {
		t.Fatalf("attachment data mismatch: got %q want %q", string(attachment.Data), string(data))
	}
}

func TestBuildAttachmentRejectsChangedFiles(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	if err := os.WriteFile(path, testPNGData, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	_, err := validateMetadata([]AttachmentMetadata{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: 999,
	}})
	if err == nil {
		t.Fatalf("expected size mismatch to fail")
	}
}

func TestBuildAttachmentRejectsZeroSizeBypass(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	if err := os.WriteFile(path, testPNGData, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	_, err := validateMetadata([]AttachmentMetadata{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: 0,
	}})
	if err == nil {
		t.Fatalf("expected missing exact size to fail")
	}
}

func TestLoadAttachmentsEnforcesLimitsBeforeReading(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	if err := os.WriteFile(path, testPNGData, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	attachments := make([]AttachmentMetadata, maxAttachments+1)
	for i := range attachments {
		attachments[i] = AttachmentMetadata{
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

	_, err = LoadAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "too many attachments") {
		t.Fatalf("expected too many attachments error, got %v", err)
	}
}

func TestLoadAttachmentsRejectsTotalSizeOverLimit(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "huge.png")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatalf("create test attachment: %v", err)
	}
	if err := os.Truncate(path, maxAttachmentBytes+1); err != nil {
		t.Fatalf("resize test attachment: %v", err)
	}

	raw, err := json.Marshal([]AttachmentMetadata{{
		Name:      "huge.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: maxAttachmentBytes + 1,
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	_, err = LoadAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "attachments exceed") {
		t.Fatalf("expected total size error, got %v", err)
	}
}

func TestLoadAttachmentsRejectsUnsupportedTypes(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "notes.txt")
	if err := os.WriteFile(path, []byte("not an image"), 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	raw, err := json.Marshal([]AttachmentMetadata{{
		Name:      "notes.txt",
		Path:      path,
		MimeType:  "text/plain",
		SizeBytes: int64(len("not an image")),
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	_, err = LoadAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "type is not supported") {
		t.Fatalf("expected unsupported type error, got %v", err)
	}
}

func TestLoadAttachmentsRejectsMismatchedImageContent(t *testing.T) {
	tmpDir := t.TempDir()
	path := filepath.Join(tmpDir, "vpn_error.png")
	data := []byte("not an image")
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatalf("write test attachment: %v", err)
	}

	raw, err := json.Marshal([]AttachmentMetadata{{
		Name:      "vpn_error.png",
		Path:      path,
		MimeType:  "image/png",
		SizeBytes: int64(len(data)),
	}})
	if err != nil {
		t.Fatalf("marshal attachments: %v", err)
	}

	_, err = LoadAttachments(string(raw))
	if err == nil || !strings.Contains(err.Error(), "content is not a supported image") {
		t.Fatalf("expected content type error, got %v", err)
	}
}
