package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	wire "github.com/getlantern/common/usermessage"
	"github.com/getlantern/lantern/lantern-core/utils"
	commonenv "github.com/getlantern/radiance/common/env"
)

type fakeUserMessageClient struct {
	message      *wire.ResolvedUserMessage
	currentErr   error
	refreshCount int
	acknowledged string
}

func (f *fakeUserMessageClient) CurrentUserMessage(context.Context) (*wire.ResolvedUserMessage, error) {
	return f.message, f.currentErr
}

func (f *fakeUserMessageClient) RefreshUserMessages(context.Context) error {
	f.refreshCount++
	return nil
}

func (f *fakeUserMessageClient) AcknowledgeUserMessage(_ context.Context, displayID string) error {
	f.acknowledged = displayID
	return nil
}

type recordingFlutterEmitter struct {
	events []*utils.FlutterEvent
}

func (r *recordingFlutterEmitter) SendEvent(event *utils.FlutterEvent) {
	r.events = append(r.events, event)
}

func TestUserMessageBridge(t *testing.T) {
	client := &fakeUserMessageClient{message: testResolvedUserMessage()}
	lc := &LanternCore{ctx: context.Background(), userMessages: client}

	encoded, err := lc.CurrentUserMessage()
	if err != nil {
		t.Fatal(err)
	}
	var got wire.ResolvedUserMessage
	if err := json.Unmarshal([]byte(encoded), &got); err != nil {
		t.Fatal(err)
	}
	if got.DisplayID != client.message.DisplayID || got.Body != client.message.Body {
		t.Fatalf("unexpected bridge message: %#v", got)
	}

	if err := lc.RefreshUserMessages(); err != nil || client.refreshCount != 1 {
		t.Fatalf("refresh: count=%d err=%v", client.refreshCount, err)
	}
	if err := lc.AcknowledgeUserMessage(client.message.DisplayID); err != nil {
		t.Fatal(err)
	}
	if client.acknowledged != client.message.DisplayID {
		t.Fatalf("acknowledged %q", client.acknowledged)
	}
	if err := lc.AcknowledgeUserMessage(""); err == nil {
		t.Fatal("expected empty display ID to fail")
	}
}

func TestUserMessageCapabilities(t *testing.T) {
	capabilities := utils.UserMessageCapabilities()
	if err := capabilities.Validate(); err != nil {
		t.Fatalf("invalid user-message capabilities: %v", err)
	}
	if len(capabilities.Surfaces) != 1 || capabilities.Surfaces[0] != wire.SurfaceSnackbar {
		t.Fatalf("unexpected user-message surfaces: %v", capabilities.Surfaces)
	}
}

func TestCurrentUserMessageNullAndError(t *testing.T) {
	client := &fakeUserMessageClient{}
	lc := &LanternCore{ctx: context.Background(), userMessages: client}

	encoded, err := lc.CurrentUserMessage()
	if err != nil || encoded != currentUserMessageNull {
		t.Fatalf("current: encoded=%q err=%v", encoded, err)
	}

	client.currentErr = errors.New("ipc unavailable")
	_, err = lc.CurrentUserMessage()
	if err == nil {
		t.Fatal("expected current error")
	}
}

func TestUserMessageAvailabilityEventIsPayloadFreeAndDeduplicated(t *testing.T) {
	client := &fakeUserMessageClient{message: testResolvedUserMessage()}
	emitter := &recordingFlutterEmitter{}
	lc := &LanternCore{
		ctx:          context.Background(),
		userMessages: client,
		eventEmitter: emitter,
	}

	lastDisplayID := ""
	lc.checkUserMessageAvailability(&lastDisplayID)
	lc.checkUserMessageAvailability(&lastDisplayID)
	if len(emitter.events) != 1 {
		t.Fatalf("got %d events", len(emitter.events))
	}
	if emitter.events[0].Type != EventTypeUserMessageAvailable || emitter.events[0].Message != "" {
		t.Fatalf("unexpected event: %#v", emitter.events[0])
	}

	client.message = nil
	lc.checkUserMessageAvailability(&lastDisplayID)
	client.message = testResolvedUserMessage()
	lc.checkUserMessageAvailability(&lastDisplayID)
	if len(emitter.events) != 2 {
		t.Fatalf("got %d events after pending reset", len(emitter.events))
	}
}

func TestRadianceVersionOverride(t *testing.T) {
	if got := (&utils.Opts{}).RadianceEnvOverrides(); got != nil {
		t.Fatalf("expected nil overrides, got %#v", got)
	}
	got := (&utils.Opts{AppVersion: "9.1.2"}).RadianceEnvOverrides()
	if got[commonenv.AppVersion.String()] != "9.1.2" || len(got) != 1 {
		t.Fatalf("unexpected overrides: %#v", got)
	}
}

func testResolvedUserMessage() *wire.ResolvedUserMessage {
	return &wire.ResolvedUserMessage{
		DisplayID:  "campaign-1:generation-2",
		CampaignID: "campaign-1",
		RevisionID: "revision-3",
		DeliveryID: "delivery-4",
		Surface:    wire.SurfaceSnackbar,
		Locale:     "en-US",
		Body:       "Localized content must stay out of events and logs.",
		ExpiresAt:  time.Now().Add(time.Hour).UTC(),
	}
}
