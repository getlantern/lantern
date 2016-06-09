package client

type Purchase struct {
	StripeToken    string `json:"stripeToken"`
	IdempotencyKey string `json:"idempotencyKey"`
	StripeEmail    string `json:"stripeEmail"`
	Plan           string `json:"plan"`
}
