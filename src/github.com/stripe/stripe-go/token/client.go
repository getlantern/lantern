// Package token provides the /tokens APIs
package token

import (
	"errors"

	stripe "github.com/stripe/stripe-go"
)

const (
	Card stripe.TokenType = "card"
	Bank stripe.TokenType = "bank_account"
	PII  stripe.TokenType = "pii"
)

// Client is used to invoke /tokens APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs a new card or bank account.
// For more details see https://stripe.com/docs/api#create_card_Token and https://stripe.com/docs/api#create_bank_account_token.
func New(params *stripe.TokenParams) (*stripe.Token, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.TokenParams) (*stripe.Token, error) {
	body := &stripe.RequestValues{}
	token := c.Key

	if len(params.Customer) > 0 {
		body.Add("customer", params.Customer)
	}

	if params.Card != nil {
		params.Card.AppendDetails(body, true)
	} else if params.Bank != nil {
		params.Bank.AppendDetails(body)
	} else if params.PII != nil {
		params.PII.AppendDetails(body)
	} else if len(params.Customer) == 0 {
		err := errors.New("Invalid Token params: either Card, Bank, or PII need to be set")
		return nil, err
	}

	if len(params.Email) > 0 {
		body.Add("email", params.Email)
	}

	params.AppendTo(body)

	tok := &stripe.Token{}
	err := c.B.Call("POST", "/tokens", token, body, &params.Params, tok)

	return tok, err
}

// Get returns the details of a token.
// For more details see https://stripe.com/docs/api#retrieve_token.
func Get(id string, params *stripe.TokenParams) (*stripe.Token, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.TokenParams) (*stripe.Token, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	token := &stripe.Token{}
	err := c.B.Call("GET", "/tokens/"+id, c.Key, body, commonParams, token)

	return token, err
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
