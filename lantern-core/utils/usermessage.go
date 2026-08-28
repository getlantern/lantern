package utils

import wire "github.com/getlantern/common/usermessage"

// UserMessageCapabilities returns the delivery features implemented by the
// Lantern UI and its platform bridges.
func UserMessageCapabilities() wire.ClientCapabilities {
	return wire.ClientCapabilities{
		Version:  wire.CapabilityUserMessagesV1,
		Surfaces: []wire.Surface{wire.SurfaceSnackbar},
		Actions: []wire.ActionType{
			wire.ActionTypeOpenHTTPSURL,
			wire.ActionTypeOpenPlans,
		},
	}
}
