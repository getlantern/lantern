package stripe

import (
	"encoding/json"
)

// Currency is the list of supported currencies.
// For more details see https://support.stripe.com/questions/which-currencies-does-stripe-support.
type Currency string

// FraudReport is the list of allowed values for reporting fraud.
// Allowed values are "fraudulent", "safe".
type FraudReport string

// ChargeParams is the set of parameters that can be used when creating or updating a charge.
// For more details see https://stripe.com/docs/api#create_charge and https://stripe.com/docs/api#update_charge.
type ChargeParams struct {
	Params
	Amount                       uint64
	Currency                     Currency
	Customer, Token              string
	Desc, Statement, Email, Dest string
	NoCapture                    bool
	Fee                          uint64
	Fraud                        FraudReport
	Source                       *SourceParams
	Shipping                     *ShippingDetails
}

// SetSource adds valid sources to a ChargeParams object,
// returning an error for unsupported sources.
func (cp *ChargeParams) SetSource(sp interface{}) error {
	source, err := SourceParamsFor(sp)
	cp.Source = source
	return err
}

// ChargeListParams is the set of parameters that can be used when listing charges.
// For more details see https://stripe.com/docs/api#list_charges.
type ChargeListParams struct {
	ListParams
	Created  int64
	Customer string
}

// CaptureParams is the set of parameters that can be used when capturing a charge.
// For more details see https://stripe.com/docs/api#charge_capture.
type CaptureParams struct {
	Params
	Amount, Fee uint64
	Email       string
}

// Charge is the resource representing a Stripe charge.
// For more details see https://stripe.com/docs/api#charges.
type Charge struct {
	Amount         uint64            `json:"amount"`
	AmountRefunded uint64            `json:"amount_refunded"`
	Captured       bool              `json:"captured"`
	Created        int64             `json:"created"`
	Currency       Currency          `json:"currency"`
	Customer       *Customer         `json:"customer"`
	Desc           string            `json:"description"`
	Dest           *Account          `json:"destination"`
	Dispute        *Dispute          `json:"dispute"`
	Email          string            `json:"receipt_email"`
	FailCode       string            `json:"failure_code"`
	FailMsg        string            `json:"failure_message"`
	Fee            *Fee              `json:"application_fee"`
	FraudDetails   *FraudDetails     `json:"fraud_details"`
	ID             string            `json:"id"`
	Invoice        *Invoice          `json:"invoice"`
	Live           bool              `json:"livemode"`
	Meta           map[string]string `json:"metadata"`
	Outcome        *ChargeOutcome    `json:"outcome"`
	Paid           bool              `json:"paid"`
	Refunded       bool              `json:"refunded"`
	Refunds        *RefundList       `json:"refunds"`
	Shipping       *ShippingDetails  `json:"shipping"`
	Source         *PaymentSource    `json:"source"`
	SourceTransfer *Transfer         `json:"source_transfer"`
	Statement      string            `json:"statement_descriptor"`
	Status         string            `json:"status"`
	Transfer       *Transfer         `json:"transfer"`
	Tx             *Transaction      `json:"balance_transaction"`
}

// ChargeList is a list of charges as retrieved from a list endpoint.
type ChargeList struct {
	ListMeta
	Values []*Charge `json:"data"`
}

// FraudDetails is the structure detailing fraud status.
type FraudDetails struct {
	UserReport   FraudReport `json:"user_report"`
	StripeReport FraudReport `json:"stripe_report"`
}

// Outcome is the charge's outcome that details whether a payment
// was accepted and why.
type ChargeOutcome struct {
	NetworkStatus string `json:"network_status"`
	Reason        string `json:"reason"`
	SellerMessage string `json:"seller_message"`
	Type          string `json:"type"`
}

// ShippingDetails is the structure containing shipping information.
type ShippingDetails struct {
	Name     string  `json:"name"`
	Address  Address `json:"address"`
	Phone    string  `json:"phone"`
	Tracking string  `json:"tracking_number"`
	Carrier  string  `json:"carrier"`
}

// AppendDetails adds the shipping details to the query string.
func (s *ShippingDetails) AppendDetails(values *RequestValues) {
	values.Add("shipping[name]", s.Name)

	values.Add("shipping[address][line1]", s.Address.Line1)
	if len(s.Address.Line2) > 0 {
		values.Add("shipping[address][line2]", s.Address.Line2)
	}
	if len(s.Address.City) > 0 {
		values.Add("shipping[address][city]", s.Address.City)
	}

	if len(s.Address.State) > 0 {
		values.Add("shipping[address][state]", s.Address.State)
	}

	if len(s.Address.Country) > 0 {
		values.Add("shipping[address][country]", s.Address.Country)
	}

	if len(s.Address.Zip) > 0 {
		values.Add("shipping[address][postal_code]", s.Address.Zip)
	}

	if len(s.Phone) > 0 {
		values.Add("shipping[phone]", s.Phone)
	}

	if len(s.Tracking) > 0 {
		values.Add("shipping[tracking_number]", s.Tracking)
	}

	if len(s.Carrier) > 0 {
		values.Add("shipping[carrier]", s.Carrier)
	}
}

// UnmarshalJSON handles deserialization of a Charge.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (c *Charge) UnmarshalJSON(data []byte) error {
	type charge Charge
	var cc charge
	err := json.Unmarshal(data, &cc)
	if err == nil {
		*c = Charge(cc)
	} else {
		// the id is surrounded by "\" characters, so strip them
		c.ID = string(data[1 : len(data)-1])
	}

	return nil
}
