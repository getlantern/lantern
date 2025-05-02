package utils

import (
	"encoding/json"
	"fmt"

	"github.com/golang-jwt/jwt"
)

type UserInfo struct {
	UserId       string `json:"user_id"`
	Email        string `json:"email"`
	DeviceId     string `json:"device_id"`
	LegacyUserId int64  `json:"legacy_user_id"`
	LegacyToken  string `json:"legacy_token"`
}

func DecodeJWT(tokenStr string) (*UserInfo, error) {
	token, _, err := new(jwt.Parser).ParseUnverified(tokenStr, jwt.MapClaims{})
	if err != nil {
		return nil, err
	}

	claimsMap, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("failed to convert claims to MapClaims")
	}

	// Convert map to JSON
	claimsJSON, err := json.Marshal(claimsMap)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal claims to JSON: %v", err)
	}

	// Decode JSON into UserClaims
	var userClaims *UserInfo
	if err := json.Unmarshal(claimsJSON, &userClaims); err != nil {
		return nil, fmt.Errorf("failed to unmarshal JSON into UserClaims: %v", err)
	}
	return userClaims, nil
}
