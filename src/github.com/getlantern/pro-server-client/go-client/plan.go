package client

type duration struct {
	Days, Months, Years int
}

type Plan struct {
	Id           string         `json:"id"`
	Description  string         `json:"description"`
	Duration     duration       `json:"duration"`
	Price        map[string]int `json:"price"`
	Subscription bool           `json:"subscription"`
	BestValue    bool           `json:"bestValue"`
}
