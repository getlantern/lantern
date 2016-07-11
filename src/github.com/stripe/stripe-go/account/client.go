// Package account provides the /account APIs
package account

import (
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

// Client is used to invoke /account APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New creates a new account.
func New(params *stripe.AccountParams) (*stripe.Account, error) {
	return getC().New(params)
}

func writeAccountParams(
	params *stripe.AccountParams, body *stripe.RequestValues,
) {
	if len(params.Country) > 0 {
		body.Add("country", params.Country)
	}

	if len(params.Email) > 0 {
		body.Add("email", params.Email)
	}

	// Country.
	if len(params.Country) > 0 {
		body.Add("country", params.Country)
	}

	if len(params.DefaultCurrency) > 0 {
		body.Add("default_currency", params.DefaultCurrency)
	}

	if params.ExternalAccount != nil {
		if len(params.ExternalAccount.Token) > 0 {
			body.Add("external_account", params.ExternalAccount.Token)
		} else {
			body.Add("external_account[object]", "bank_account")
			body.Add("external_account[account_number]", params.ExternalAccount.Account)
			body.Add("external_account[country]", params.ExternalAccount.Country)
			body.Add("external_account[currency]", params.ExternalAccount.Currency)

			if len(params.ExternalAccount.Routing) > 0 {
				body.Add("external_account[routing_number]", params.ExternalAccount.Routing)
			}
		}
	}

	if len(params.Statement) > 0 {
		body.Add("statement_descriptor", params.Statement)
	}

	if len(params.BusinessName) > 0 {
		body.Add("business_name", params.BusinessName)
	}

	if len(params.BusinessPrimaryColor) > 0 {
		body.Add("business_primary_color", params.BusinessPrimaryColor)
	}

	if len(params.BusinessUrl) > 0 {
		body.Add("business_url", params.BusinessUrl)
	}

	if len(params.SupportPhone) > 0 {
		body.Add("support_phone", params.SupportPhone)
	}

	if len(params.SupportEmail) > 0 {
		body.Add("support_email", params.SupportEmail)
	}

	if len(params.SupportUrl) > 0 {
		body.Add("support_url", params.SupportUrl)
	}

	if params.LegalEntity != nil {
		params.LegalEntity.AppendDetails(body)
	}

	if params.TransferSchedule != nil {
		params.TransferSchedule.AppendDetails(body)
	}

	if params.TOSAcceptance != nil {
		params.TOSAcceptance.AppendDetails(body)
	}
}

func (c Client) New(params *stripe.AccountParams) (*stripe.Account, error) {
	body := &stripe.RequestValues{}
	body.Add("managed", strconv.FormatBool(params.Managed))
	body.Add("debit_negative_balances", strconv.FormatBool(params.DebitNegativeBal))

	writeAccountParams(params, body)

	if params.TOSAcceptance != nil {
		params.TOSAcceptance.AppendDetails(body)
	}

	params.AppendTo(body)

	acct := &stripe.Account{}
	err := c.B.Call("POST", "/accounts", c.Key, body, &params.Params, acct)

	return acct, err
}

// Get returns the details of an account.
func Get() (*stripe.Account, error) {
	return getC().Get()
}

func (c Client) Get() (*stripe.Account, error) {
	account := &stripe.Account{}
	err := c.B.Call("GET", "/account", c.Key, nil, nil, account)

	return account, err
}

// GetByID returns the details of your account.
func GetByID(id string, params *stripe.AccountParams) (*stripe.Account, error) {
	return getC().GetByID(id, params)
}

func (c Client) GetByID(id string, params *stripe.AccountParams) (*stripe.Account, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	account := &stripe.Account{}
	err := c.B.Call("GET", "/accounts/"+id, c.Key, body, commonParams, account)

	return account, err
}

// Update updates the details of an account.
func Update(id string, params *stripe.AccountParams) (*stripe.Account, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.AccountParams) (*stripe.Account, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}

		writeAccountParams(params, body)

		if params.TOSAcceptance != nil {
			params.TOSAcceptance.AppendDetails(body)
		}

		params.AppendTo(body)
	}

	acct := &stripe.Account{}
	err := c.B.Call("POST", "/accounts/"+id, c.Key, body, commonParams, acct)

	return acct, err
}

// Del deletes an account
func Del(id string) (*stripe.Account, error) {
	return getC().Del(id)
}

func (c Client) Del(id string) (*stripe.Account, error) {
	acct := &stripe.Account{}
	err := c.B.Call("DELETE", "/accounts/"+id, c.Key, nil, nil, acct)

	return acct, err
}

// Reject rejects an account
func Reject(id string, params *stripe.AccountRejectParams) (*stripe.Account, error) {
	return getC().Reject(id, params)
}

func (c Client) Reject(id string, params *stripe.AccountRejectParams) (*stripe.Account, error) {
	body := &stripe.RequestValues{}
	if len(params.Reason) > 0 {
		body.Add("reason", params.Reason)
	}
	acct := &stripe.Account{}
	err := c.B.Call("POST", "/accounts/"+id+"/reject", c.Key, body, nil, acct)

	return acct, err
}

// List lists your accounts.
func List(params *stripe.AccountListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.AccountListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.AccountList{}
		err := c.B.Call("GET", "/accounts", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Accounts.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Account returns the most recent Account
// visited by a call to Next.
func (i *Iter) Account() *stripe.Account {
	return i.Current().(*stripe.Account)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
