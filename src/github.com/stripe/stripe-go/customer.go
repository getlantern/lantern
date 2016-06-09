package stripe

import (
	"encoding/json"
)

// CustomerParams is the set of parameters that can be used when creating or updating a customer.
// For more details see https://stripe.com/docs/api#create_customer and https://stripe.com/docs/api#update_customer.
type CustomerParams struct {
	Params
	Balance       int64
	Token, Coupon string
	Source        *SourceParams
	Desc, Email   string
	Plan          string
	Quantity      uint64
	TrialEnd      int64
	DefaultSource string
	Shipping      *CustomerShippingDetails
	BusinessVatID string
}

// SetSource adds valid sources to a CustomerParams object,
// returning an error for unsupported sources.
func (cp *CustomerParams) SetSource(sp interface{}) error {
	source, err := SourceParamsFor(sp)
	cp.Source = source
	return err
}

// CustomerListParams is the set of parameters that can be used when listing customers.
// For more details see https://stripe.com/docs/api#list_customers.
type CustomerListParams struct {
	ListParams
	Created int64
}

// Customer is the resource representing a Stripe customer.
// For more details see https://stripe.com/docs/api#customers.
type Customer struct {
	ID            string                   `json:"id"`
	Live          bool                     `json:"livemode"`
	Sources       *SourceList              `json:"sources"`
	Created       int64                    `json:"created"`
	Balance       int64                    `json:"account_balance"`
	Currency      Currency                 `json:"currency"`
	DefaultSource *PaymentSource           `json:"default_source"`
	Delinquent    bool                     `json:"delinquent"`
	Desc          string                   `json:"description"`
	Discount      *Discount                `json:"discount"`
	Email         string                   `json:"email"`
	Meta          map[string]string        `json:"metadata"`
	Subs          *SubList                 `json:"subscriptions"`
	Deleted       bool                     `json:"deleted"`
	Shipping      *CustomerShippingDetails `json:"shipping"`
	BusinessVatID string                   `json:"business_vat_id"`
}

// CustomerList is a list of customers as retrieved from a list endpoint.
type CustomerList struct {
	ListMeta
	Values []*Customer `json:"data"`
}

// CustomerShippingDetails is the structure containing shipping information.
type CustomerShippingDetails struct {
	Name    string  `json:"name"`
	Address Address `json:"address"`
	Phone   string  `json:"phone"`
}

// AppendDetails adds the shipping details to the query string.
func (s *CustomerShippingDetails) AppendDetails(values *RequestValues) {
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
}

// UnmarshalJSON handles deserialization of a Customer.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (c *Customer) UnmarshalJSON(data []byte) error {
	type customer Customer
	var cc customer
	err := json.Unmarshal(data, &cc)
	if err == nil {
		*c = Customer(cc)
	} else {
		// the id is surrounded by "\" characters, so strip them
		c.ID = string(data[1 : len(data)-1])
	}

	return nil
}
