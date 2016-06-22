package client

type Auth struct {
	ID       int `json:"userId"`
	DeviceID string
	Token    string `json:"token"`
}
