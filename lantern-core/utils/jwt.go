package utils

import (
	"encoding/json"
	"fmt"

	"github.com/golang-jwt/jwt/v5"
)

type UserInfo struct {
	UserId       string `json:"user_id"`
	Email        string `json:"email"`
	DeviceId     string `json:"device_id"`
	LegacyUserId int64  `json:"legacy_user_id"`
	LegacyToken  string `json:"legacy_token"`
}

func DecodeJWT(tokenStr string) (*UserInfo, error) {
	claims := jwt.MapClaims{}
	token, _, err := new(jwt.Parser).ParseUnverified(tokenStr, &claims)
	if err != nil {
		return nil, err
	}
	// Convert MapClaims to JSON
	claimsJSON, err := json.Marshal(token.Claims)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal claims: %v", err)
	}
	var userInfo UserInfo
	if err := json.Unmarshal(claimsJSON, &userInfo); err != nil {
		return nil, fmt.Errorf("failed to unmarshal to UserInfo: %v", err)
	}

	return &userInfo, nil
}
