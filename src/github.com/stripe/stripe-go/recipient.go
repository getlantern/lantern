package stripe

import "encoding/json"

// RecipientType is the list of allowed values for the recipient's type.
// Allowed values are "individual", "corporation".
type RecipientType string

// RecipientParams is the set of parameters that can be used when creating or updating recipients.
// For more details see https://stripe.com/docs/api#create_recipient and https://stripe.com/docs/api#update_recipient.
type RecipientParams struct {
	Params
	Name                      string
	Type                      RecipientType
	TaxID, Token, Email, Desc string
	Bank                      *BankAccountParams
	Card                      *CardParams
	DefaultCard               string
}

// RecipientListParams is the set of parameters that can be used when listing recipients.
// For more details see https://stripe.com/docs/api#list_recipients.
type RecipientListParams struct {
	ListParams
	Verified bool
}

// Recipient is the resource representing a Stripe recipient.
// For more details see https://stripe.com/docs/api#recipients.
type Recipient struct {
	ID          string            `json:"id"`
	Live        bool              `json:"livemode"`
	Created     int64             `json:"created"`
	Type        RecipientType     `json:"type"`
	Bank        *BankAccount      `json:"active_account"`
	Desc        string            `json:"description"`
	Email       string            `json:"email"`
	Meta        map[string]string `json:"metadata"`
	Name        string            `json:"name"`
	Cards       *CardList         `json:"cards"`
	DefaultCard *Card             `json:"default_card"`
	Deleted     bool              `json:"deleted"`
}

// RecipientList is a list of recipients as retrieved from a list endpoint.
type RecipientList struct {
	ListMeta
	Values []*Recipient `json:"data"`
}

// UnmarshalJSON handles deserialization of a Recipient.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (r *Recipient) UnmarshalJSON(data []byte) error {
	type recipient Recipient
	var rr recipient
	err := json.Unmarshal(data, &rr)
	if err == nil {
		*r = Recipient(rr)
	} else {
		// the id is surrounded by "\" characters, so strip them
		r.ID = string(data[1 : len(data)-1])
	}

	return nil
}
