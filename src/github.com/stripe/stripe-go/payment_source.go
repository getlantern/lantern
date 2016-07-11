package stripe

import (
	"encoding/json"
	"fmt"
)

// SourceParams is a union struct used to describe an
// arbitrary payment source.
type SourceParams struct {
	Token string
	Card  *CardParams
}

// AppendDetails adds the source's details to the query string values.
// For cards: when creating a new one, the parameters are passed as a dictionary, but
// on updates they are simply the parameter name.
func (sp *SourceParams) AppendDetails(values *RequestValues, creating bool) {
	if len(sp.Token) > 0 {
		values.Add("source", sp.Token)
	} else if sp.Card != nil {
		sp.Card.AppendDetails(values, creating)
	}
}

// CustomerSourceParams are used to manipulate a given Stripe
// Customer object's payment sources.
// For more details see https://stripe.com/docs/api#sources
type CustomerSourceParams struct {
	Params
	Customer string
	Source   *SourceParams
}

// SourceVerifyParams are used to verify a customer source
// For more details see https://stripe.com/docs/guides/ach-beta
type SourceVerifyParams struct {
	Params
	Customer string
	Amounts  [2]uint8
}

// SetSource adds valid sources to a CustomerSourceParams object,
// returning an error for unsupported sources.
func (cp *CustomerSourceParams) SetSource(sp interface{}) error {
	source, err := SourceParamsFor(sp)
	cp.Source = source
	return err
}

// SourceParamsFor creates SourceParams objects around supported
// payment sources, returning errors if not.
//
// Currently supported source types are Card (CardParams) and
// Tokens/IDs (string), where Tokens could be single use card
// tokens or bitcoin receiver ids
func SourceParamsFor(obj interface{}) (*SourceParams, error) {
	var sp *SourceParams
	var err error
	switch p := obj.(type) {
	case *CardParams:
		sp = &SourceParams{
			Card: p,
		}
	case string:
		sp = &SourceParams{
			Token: p,
		}
	default:
		err = fmt.Errorf("Unsupported source type %s", p)
	}
	return sp, err
}

// Displayer provides a human readable representation of a struct
type Displayer interface {
	Display() string
}

// PaymentSourceType consts represent valid payment sources.
type PaymentSourceType string

const (
	// PaymentSourceBankAccount is a constant representing a payment source
	// which is a bank account.
	PaymentSourceBankAccount PaymentSourceType = "bank_account"

	// PaymentSourceBitcoinReceiver is a constant representing a payment source
	// which is a Bitcoin receiver.
	PaymentSourceBitcoinReceiver PaymentSourceType = "bitcoin_receiver"

	// PaymentSourceCard is a constant representing a payment source which is a
	// card.
	PaymentSourceCard PaymentSourceType = "card"
)

// PaymentSource describes the payment source used to make a Charge.
// The Type should indicate which object is fleshed out (eg. BitcoinReceiver or Card)
// For more details see https://stripe.com/docs/api#retrieve_charge
type PaymentSource struct {
	Type            PaymentSourceType `json:"object"`
	ID              string            `json:"id"`
	Card            *Card             `json:"-"`
	BitcoinReceiver *BitcoinReceiver  `json:"-"`
	BankAccount     *BankAccount      `json:"-"`
	Deleted         bool              `json:"deleted"`
}

// SourceList is a list object for cards.
type SourceList struct {
	ListMeta
	Values []*PaymentSource `json:"data"`
}

// SourceListParams are used to enumerate the payment sources that are attached
// to a Customer.
type SourceListParams struct {
	ListParams
	Customer string
}

// Display human readable representation of source.
func (s *PaymentSource) Display() string {
	switch s.Type {
	case PaymentSourceBitcoinReceiver:
		return s.BitcoinReceiver.Display()
	case PaymentSourceCard:
		return s.Card.Display()
	case PaymentSourceBankAccount:
		return s.BankAccount.Display()
	}

	return ""
}

// UnmarshalJSON handles deserialization of a PaymentSource.
// This custom unmarshaling is needed because the specific
// type of payment instrument it refers to is specified in the JSON
func (s *PaymentSource) UnmarshalJSON(data []byte) error {
	type source PaymentSource
	var ss source
	err := json.Unmarshal(data, &ss)
	if err == nil {
		*s = PaymentSource(ss)

		switch s.Type {
		case PaymentSourceBankAccount:
			json.Unmarshal(data, &s.BankAccount)
		case PaymentSourceBitcoinReceiver:
			json.Unmarshal(data, &s.BitcoinReceiver)
		case PaymentSourceCard:
			json.Unmarshal(data, &s.Card)
		}
	} else {
		// the id is surrounded by "\" characters, so strip them
		s.ID = string(data[1 : len(data)-1])
	}

	return nil
}

// MarshalJSON handles serialization of a PaymentSource.
// This custom marshaling is needed because the specific type
// of payment instrument it represents is specified by the PaymentSourceType
func (s *PaymentSource) MarshalJSON() ([]byte, error) {
	var target interface{}

	switch s.Type {
	case PaymentSourceBitcoinReceiver:
		target = struct {
			Type PaymentSourceType `json:"object"`
			*BitcoinReceiver
		}{
			Type:            s.Type,
			BitcoinReceiver: s.BitcoinReceiver,
		}
	case PaymentSourceCard:
		var customerID *string
		if s.Card.Customer != nil {
			customerID = &s.Card.Customer.ID
		}

		target = struct {
			Type     PaymentSourceType `json:"object"`
			Customer *string           `json:"customer"`
			*Card
		}{
			Type:     s.Type,
			Customer: customerID,
			Card:     s.Card,
		}

	case "":
		target = s.ID
	}

	return json.Marshal(target)
}
