package stripe

// TokenType is the list of allowed values for a token's type.
// Allowed values are "card", "bank_account".
type TokenType string

// TokenParams is the set of parameters that can be used when creating a token.
// For more details see https://stripe.com/docs/api#create_card_token and https://stripe.com/docs/api#create_bank_account_token.
type TokenParams struct {
	Params
	Card     *CardParams
	Bank     *BankAccountParams
	PII      *PIIParams
	Customer string
	// Email is an undocumented parameter used by Stripe Checkout
	// It may be removed from the API without notice.
	Email string
}

// Token is the resource representing a Stripe token.
// For more details see https://stripe.com/docs/api#tokens.
type Token struct {
	ID       string       `json:"id"`
	Live     bool         `json:"livemode"`
	Created  int64        `json:"created"`
	Type     TokenType    `json:"type"`
	Used     bool         `json:"used"`
	Bank     *BankAccount `json:"bank_account"`
	Card     *Card        `json:"card"`
	ClientIP string       `json:"client_ip"`
	// Email is an undocumented field but included for all tokens created
	// with Stripe Checkout.
	Email string `json:"email"`
}

// PIIParams are parameters for personal identifiable information (PII).
type PIIParams struct {
	Params
	PersonalIDNumber string
}

// AppendDetails adds the PII data's details to the query string values.
func (p *PIIParams) AppendDetails(values *RequestValues) {
	values.Add("pii[personal_id_number]", p.PersonalIDNumber)
}
