package client

type Response struct {
	Status string `json:"status"`
	Error  string `json:"error"`
}

type UserResponse struct {
	Response `json:",inline"`
	User     `json:",inline"`
}

type AutoconfResponse struct {
	Response      `json:",inline"`
	Email         string `json:"email"`
	AutoconfToken string `json:"autoconfToken"`
}

type CodeResponse struct {
	Response `json:",inline"`
	Code     string `json:"code"`
}
