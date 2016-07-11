// Package recipient provides the /recipients APIs
package recipient

import (
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

const (
	Individual stripe.RecipientType = "individual"
	Corp       stripe.RecipientType = "corporation"
)

// Client is used to invoke /recipients APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs a new recipient.
// For more details see https://stripe.com/docs/api#create_recipient.
func New(params *stripe.RecipientParams) (*stripe.Recipient, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.RecipientParams) (*stripe.Recipient, error) {
	body := &stripe.RequestValues{}
	body.Add("name", params.Name)
	body.Add("type", string(params.Type))

	if params.Bank != nil {
		if len(params.Bank.Token) > 0 {
			body.Add("bank_account", params.Bank.Token)
		} else {
			params.Bank.AppendDetails(body)
		}
	}

	if len(params.Token) > 0 {
		body.Add("card", params.Token)
	} else if params.Card != nil {
		params.Card.AppendDetails(body, true)
	}

	if len(params.TaxID) > 0 {
		body.Add("tax_id", params.TaxID)
	}

	if len(params.Email) > 0 {
		body.Add("email", params.Email)
	}

	if len(params.Desc) > 0 {
		body.Add("description", params.Desc)
	}
	params.AppendTo(body)

	recipient := &stripe.Recipient{}
	err := c.B.Call("POST", "/recipients", c.Key, body, &params.Params, recipient)

	return recipient, err
}

// Get returns the details of a recipient.
// For more details see https://stripe.com/docs/api#retrieve_recipient.
func Get(id string, params *stripe.RecipientParams) (*stripe.Recipient, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.RecipientParams) (*stripe.Recipient, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	recipient := &stripe.Recipient{}
	err := c.B.Call("GET", "/recipients/"+id, c.Key, body, commonParams, recipient)

	return recipient, err
}

// Update updates a recipient's properties.
// For more details see https://stripe.com/docs/api#update_recipient.
func Update(id string, params *stripe.RecipientParams) (*stripe.Recipient, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.RecipientParams) (*stripe.Recipient, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}

		if len(params.Name) > 0 {
			body.Add("name", params.Name)
		}

		if params.Bank != nil {
			if len(params.Bank.Token) > 0 {
				body.Add("bank_account", params.Bank.Token)
			} else {
				params.Bank.AppendDetails(body)
			}
		}

		if len(params.Token) > 0 {
			body.Add("card", params.Token)
		} else if params.Card != nil {
			params.Card.AppendDetails(body, true)
		}

		if len(params.TaxID) > 0 {
			body.Add("tax_id", params.TaxID)
		}

		if len(params.DefaultCard) > 0 {
			body.Add("default_card", params.DefaultCard)
		}

		if len(params.Email) > 0 {
			body.Add("email", params.Email)
		}

		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		params.AppendTo(body)
	}

	recipient := &stripe.Recipient{}
	err := c.B.Call("POST", "/recipients/"+id, c.Key, body, commonParams, recipient)

	return recipient, err
}

// Del removes a recipient.
// For more details see https://stripe.com/docs/api#delete_recipient.
func Del(id string) (*stripe.Recipient, error) {
	return getC().Del(id)
}

func (c Client) Del(id string) (*stripe.Recipient, error) {
	recipient := &stripe.Recipient{}
	err := c.B.Call("DELETE", "/recipients/"+id, c.Key, nil, nil, recipient)

	return recipient, err
}

// List returns a list of recipients.
// For more details see https://stripe.com/docs/api#list_recipients.
func List(params *stripe.RecipientListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.RecipientListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.Verified {
			body.Add("verified", strconv.FormatBool(true))
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.RecipientList{}
		err := c.B.Call("GET", "/recipients", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Recipients.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Recipient returns the most recent Recipient
// visited by a call to Next.
func (i *Iter) Recipient() *stripe.Recipient {
	return i.Current().(*stripe.Recipient)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
