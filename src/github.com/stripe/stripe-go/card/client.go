// Package card provides the /cards APIs
package card

import (
	"errors"
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

const (
	BrandUnknown stripe.CardBrand = "Unknown"
	Visa         stripe.CardBrand = "Visa"
	Amex         stripe.CardBrand = "American Express"
	MasterCard   stripe.CardBrand = "MasterCard"
	Discover     stripe.CardBrand = "Discover"
	JCB          stripe.CardBrand = "JCB"
	DinersClub   stripe.CardBrand = "Diners Club"

	Pass      stripe.Verification = "pass"
	Fail      stripe.Verification = "fail"
	Unchecked stripe.Verification = "unchecked"

	Credit         stripe.CardFunding = "credit"
	Debit          stripe.CardFunding = "debit"
	Prepaid        stripe.CardFunding = "prepaid"
	FundingUnknown stripe.CardFunding = "unknown"
)

// Client is used to invoke /cards APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs new cards either for a customer or recipient.
// For more details see https://stripe.com/docs/api#create_card.
func New(params *stripe.CardParams) (*stripe.Card, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.CardParams) (*stripe.Card, error) {
	body := &stripe.RequestValues{}
	params.AppendDetails(body, true)
	params.AppendTo(body)

	card := &stripe.Card{}
	var err error

	if len(params.Account) > 0 {
		if params.Default {
			body.Add("default_for_currency", strconv.FormatBool(params.Default))
		}
		err = c.B.Call("POST", fmt.Sprintf("/accounts/%v/external_accounts", params.Account), c.Key, body, &params.Params, card)
	} else if len(params.Customer) > 0 {
		err = c.B.Call("POST", fmt.Sprintf("/customers/%v/cards", params.Customer), c.Key, body, &params.Params, card)
	} else if len(params.Recipient) > 0 {
		err = c.B.Call("POST", fmt.Sprintf("/recipients/%v/cards", params.Recipient), c.Key, body, &params.Params, card)
	} else {
		err = errors.New("Invalid card params: either account, customer or recipient need to be set")
	}

	return card, err
}

// Get returns the details of a card.
// For more details see https://stripe.com/docs/api#retrieve_card.
func Get(id string, params *stripe.CardParams) (*stripe.Card, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.CardParams) (*stripe.Card, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	card := &stripe.Card{}
	var err error

	if len(params.Account) > 0 {
		err = c.B.Call("GET", fmt.Sprintf("/accounts/%v/external_accounts/%v", params.Account, id), c.Key, body, commonParams, card)
	} else if len(params.Customer) > 0 {
		err = c.B.Call("GET", fmt.Sprintf("/customers/%v/cards/%v", params.Customer, id), c.Key, body, commonParams, card)
	} else if len(params.Recipient) > 0 {
		err = c.B.Call("GET", fmt.Sprintf("/recipients/%v/cards/%v", params.Recipient, id), c.Key, body, commonParams, card)
	} else {
		err = errors.New("Invalid card params: either account, customer or recipient need to be set")
	}

	return card, err
}

// Update updates a card's properties.
// For more details see	https://stripe.com/docs/api#update_card.
func Update(id string, params *stripe.CardParams) (*stripe.Card, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.CardParams) (*stripe.Card, error) {
	body := &stripe.RequestValues{}
	params.AppendDetails(body, false)
	params.AppendTo(body)

	card := &stripe.Card{}
	var err error

	if len(params.Account) > 0 {
		if params.Default {
			body.Add("default_for_currency", strconv.FormatBool(params.Default))
		}
		err = c.B.Call("POST", fmt.Sprintf("/accounts/%v/external_accounts/%v", params.Account, id), c.Key, body, &params.Params, card)
	} else if len(params.Customer) > 0 {
		err = c.B.Call("POST", fmt.Sprintf("/customers/%v/cards/%v", params.Customer, id), c.Key, body, &params.Params, card)
	} else if len(params.Recipient) > 0 {
		err = c.B.Call("POST", fmt.Sprintf("/recipients/%v/cards/%v", params.Recipient, id), c.Key, body, &params.Params, card)
	} else {
		err = errors.New("Invalid card params: either account, customer or recipient need to be set")
	}

	return card, err
}

// Del removes a card.
// For more details see https://stripe.com/docs/api#delete_card.
func Del(id string, params *stripe.CardParams) (*stripe.Card, error) {
	return getC().Del(id, params)
}

func (c Client) Del(id string, params *stripe.CardParams) (*stripe.Card, error) {
	card := &stripe.Card{}
	var err error

	if len(params.Account) > 0 {
		err = c.B.Call("DELETE", fmt.Sprintf("/accounts/%v/external_accounts/%v", params.Account, id), c.Key, nil, &params.Params, card)
	} else if len(params.Customer) > 0 {
		err = c.B.Call("DELETE", fmt.Sprintf("/customers/%v/cards/%v", params.Customer, id), c.Key, nil, &params.Params, card)
	} else if len(params.Recipient) > 0 {
		err = c.B.Call("DELETE", fmt.Sprintf("/recipients/%v/cards/%v", params.Recipient, id), c.Key, nil, &params.Params, card)
	} else {
		err = errors.New("Invalid card params: either account, customer or recipient need to be set")
	}

	return card, err
}

// List returns a list of cards.
// For more details see https://stripe.com/docs/api#list_cards.
func List(params *stripe.CardListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.CardListParams) *Iter {
	body := &stripe.RequestValues{}
	var lp *stripe.ListParams
	var p *stripe.Params

	params.AppendTo(body)
	lp = &params.ListParams
	p = params.ToParams()

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.CardList{}
		var err error

		if len(params.Account) > 0 {
			err = c.B.Call("GET", fmt.Sprintf("/accounts/%v/external_accounts", params.Account), c.Key, b, p, list)
		} else if len(params.Customer) > 0 {
			err = c.B.Call("GET", fmt.Sprintf("/customers/%v/cards", params.Customer), c.Key, b, p, list)
		} else if len(params.Recipient) > 0 {
			err = c.B.Call("GET", fmt.Sprintf("/recipients/%v/cards", params.Recipient), c.Key, b, p, list)
		} else {
			err = errors.New("Invalid card params: either account, customer or recipient need to be set")
		}

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Cards.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Card returns the most recent Card
// visited by a call to Next.
func (i *Iter) Card() *stripe.Card {
	return i.Current().(*stripe.Card)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
