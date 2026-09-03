package utils

import wire "github.com/getlantern/common/usermessage"

// UserMessageCapabilities reports what the current UI can render and handle.
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
