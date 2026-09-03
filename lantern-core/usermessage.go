package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"time"

	wire "github.com/getlantern/common/usermessage"
)

const (
	currentUserMessageNull       = "null"
	userMessageIPCRequestTimeout = 10 * time.Second
)

type userMessageClient interface {
	CurrentUserMessage(context.Context) (*wire.ResolvedUserMessage, error)
	UserMessageEvents(context.Context, func()) error
	RefreshUserMessages(context.Context) error
	AcknowledgeUserMessage(context.Context, string) error
	SetUserMessageActivity(context.Context, bool) error
}

// CurrentUserMessage returns the pending message as common-contract JSON. It
// returns an explicit null so every platform bridge handles an empty result the
// same way.
func (lc *LanternCore) CurrentUserMessage() (string, error) {
	if lc.userMessages == nil {
		return currentUserMessageNull, nil
	}
	ctx, cancel := context.WithTimeout(lc.ctx, userMessageIPCRequestTimeout)
	defer cancel()
	message, err := lc.userMessages.CurrentUserMessage(ctx)
	if err != nil {
		return "", err
	}
	if message == nil {
		return currentUserMessageNull, nil
	}
	encoded, err := json.Marshal(message)
	if err != nil {
		return "", err
	}
	return string(encoded), nil
}

// RefreshUserMessages asks Radiance to check for a message now.
func (lc *LanternCore) RefreshUserMessages() error {
	if lc.userMessages == nil {
		return errors.New("user-message subsystem is not initialized")
	}
	ctx, cancel := context.WithTimeout(lc.ctx, userMessageIPCRequestTimeout)
	defer cancel()
	return lc.userMessages.RefreshUserMessages(ctx)
}

// AcknowledgeUserMessage records that the UI displayed displayID.
func (lc *LanternCore) AcknowledgeUserMessage(displayID string) error {
	if lc.userMessages == nil {
		return errors.New("user-message subsystem is not initialized")
	}
	if displayID == "" {
		return errors.New("display ID is required")
	}
	ctx, cancel := context.WithTimeout(lc.ctx, userMessageIPCRequestTimeout)
	defer cancel()
	return lc.userMessages.AcknowledgeUserMessage(ctx, displayID)
}

// SetUserMessageActivity pauses or resumes message polling for the app lifecycle.
func (lc *LanternCore) SetUserMessageActivity(active bool) error {
	if lc.userMessages == nil {
		return errors.New("user-message subsystem is not initialized")
	}
	ctx, cancel := context.WithTimeout(lc.ctx, userMessageIPCRequestTimeout)
	defer cancel()
	return lc.userMessages.SetUserMessageActivity(ctx, active)
}

func (lc *LanternCore) listenUserMessageAvailability() {
	err := lc.userMessages.UserMessageEvents(lc.ctx, func() {
		lc.notifyFlutter(EventTypeUserMessageAvailable, "")
	})
	if err != nil && !errors.Is(err, context.Canceled) {
		slog.Debug("User-message event stream ended", "error", err)
	}
}
