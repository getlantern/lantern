package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
)

const currentUserMessageNull = "null"

// CurrentUserMessage returns Radiance's durable pending message as the common
// wire JSON. A null result is explicit so every bridge has identical semantics.
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

// RefreshUserMessages asks Radiance to run an immediate eligibility refresh.
func (lc *LanternCore) RefreshUserMessages() error {
	if lc.userMessages == nil {
		return errors.New("user-message subsystem is not initialized")
	}
	ctx, cancel := context.WithTimeout(lc.ctx, userMessageIPCRequestTimeout)
	defer cancel()
	return lc.userMessages.RefreshUserMessages(ctx)
}

// AcknowledgeUserMessage records that the UI actually displayed displayID.
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
