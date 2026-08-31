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
	currentUserMessageNull          = "null"
	userMessageAvailabilityInterval = 5 * time.Second
	userMessageIPCRequestTimeout    = 10 * time.Second
)

type userMessageClient interface {
	CurrentUserMessage(context.Context) (*wire.ResolvedUserMessage, error)
	RefreshUserMessages(context.Context) error
	AcknowledgeUserMessage(context.Context, string) error
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

func (lc *LanternCore) listenUserMessageAvailability() {
	ticker := time.NewTicker(userMessageAvailabilityInterval)
	defer ticker.Stop()

	lastDisplayID := ""
	lc.checkUserMessageAvailability(&lastDisplayID)
	for {
		select {
		case <-lc.ctx.Done():
			return
		case <-ticker.C:
			lc.checkUserMessageAvailability(&lastDisplayID)
		}
	}
}

// This only polls the local Radiance bridge; Radiance still owns cloud polling.
// Tracking the display ID lets us notify Flutter without putting message copy
// on the event channel.
func (lc *LanternCore) checkUserMessageAvailability(lastDisplayID *string) {
	ctx, cancel := context.WithTimeout(lc.ctx, userMessageIPCRequestTimeout)
	defer cancel()
	message, err := lc.userMessages.CurrentUserMessage(ctx)
	if err != nil {
		slog.Debug("Unable to inspect pending user message", "error", err)
		return
	}
	if message == nil {
		*lastDisplayID = ""
		return
	}
	if message.DisplayID == *lastDisplayID {
		return
	}
	*lastDisplayID = message.DisplayID
	lc.notifyFlutter(EventTypeUserMessageAvailable, "")
}
