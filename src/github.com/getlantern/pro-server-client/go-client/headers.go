package client

type Auth struct {
	ID       string `json:"userId"`
	DeviceID string
	Token    string `json:"token"`
}
