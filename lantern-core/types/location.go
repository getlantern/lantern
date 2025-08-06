package types

// "github.com/getlantern/radiance/client/boxoptions"

type LocationType string

const (
	LocationAuto          LocationType = "auto"
	LocationPrivateServer LocationType = "privateServer"
	LocationLantern       LocationType = "lanternLocation"
)

// func LocationGroupAndTag(locationType LocationType, tag string) (string, string, error) {
// 	switch locationType {
// 	case LocationAuto:
// 		return boxoptions.ServerGroupLantern, boxoptions.LanternAutoTag, nil
// 	case LocationPrivateServer:
// 		return boxoptions.ServerGroupUser, tag, nil
// 	case LocationLantern:
// 		return boxoptions.ServerGroupLantern, tag, nil
// 	default:
// 		return "", "", fmt.Errorf("invalid location type: %s", locationType)
// 	}
// }
