package client

import (
	"net/http"
	"strconv"
)

type User struct {
	Email         string `json:"email"`
	PhoneNumber   string `json:"telephone"`
	UserStatus    string `json:"userStatus"`
	Locale        string `json:"locale"`
	Expiration    int64  `json:"expiration"`
	AutoconfToken string `json:"autoconfToken"`
	Subscription  string `json:"subscription"`
	Code          string `json:"code"`
	Referral      string `json:"referral"`
	Auth          `json:",inline"`
}

func (u User) headers() http.Header {
	h := http.Header{}
	// auto headers
	if u.Auth.DeviceID != "" {
		h[XLanternDeviceID] = []string{u.Auth.DeviceID}
	}
	if u.ID != 0 {
		h[XLanternUserID] = []string{strconv.Itoa(u.ID)}
	}
	if u.Auth.Token != "" {
		h[XLanternProToken] = []string{u.Auth.Token}
	}
	return h
}
