// Package transfer provides the /transfers APIs
package transfer

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

const (
	Paid     stripe.TransferStatus = "paid"
	Pending  stripe.TransferStatus = "pending"
	Transit  stripe.TransferStatus = "in_transit"
	Failed   stripe.TransferStatus = "failed"
	Canceled stripe.TransferStatus = "canceled"

	Card          stripe.TransferType = "card"
	Bank          stripe.TransferType = "bank_account"
	StripeAccount stripe.TransferType = "stripe_account"

	SourceAlipay  stripe.TransferSourceType = "alipay_account"
	SourceBank    stripe.TransferSourceType = "bank_account"
	SourceBitcoin stripe.TransferSourceType = "bitcoin_receiver"
	SourceCard    stripe.TransferSourceType = "card"

	InsufficientFunds    stripe.TransferFailCode = "insufficient_funds"
	AccountClosed        stripe.TransferFailCode = "account_closed"
	NoAccount            stripe.TransferFailCode = "no_account"
	InvalidAccountNumber stripe.TransferFailCode = "invalid_account_number"
	DebitNotAuth         stripe.TransferFailCode = "debit_not_authorized"
	BankOwnerChanged     stripe.TransferFailCode = "bank_ownership_changed"
	AccountFrozen        stripe.TransferFailCode = "account_frozen"
	CouldNotProcess      stripe.TransferFailCode = "could_not_process"
	BankAccountRestrict  stripe.TransferFailCode = "bank_account_restricted"
	InvalidCurrency      stripe.TransferFailCode = "invalid_currency"
)

// Client is used to invoke /transfers APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs a new transfer.
// For more details see https://stripe.com/docs/api#create_transfer.
func New(params *stripe.TransferParams) (*stripe.Transfer, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.TransferParams) (*stripe.Transfer, error) {
	body := &stripe.RequestValues{}
	body.Add("amount", strconv.FormatInt(params.Amount, 10))
	body.Add("currency", string(params.Currency))

	if len(params.Recipient) > 0 {
		body.Add("recipient", params.Recipient)
	}

	if len(params.Bank) > 0 {
		body.Add("bank_account", params.Bank)
	} else if len(params.Card) > 0 {
		body.Add("card", params.Card)
	}

	if len(params.Desc) > 0 {
		body.Add("description", params.Desc)
	}

	if len(params.Statement) > 0 {
		body.Add("statement_descriptor", params.Statement)
	}

	if len(params.Dest) > 0 {
		body.Add("destination", params.Dest)
	}

	if len(params.SourceTx) > 0 {
		body.Add("source_transaction", params.SourceTx)
	}

	if params.Fee > 0 {
		body.Add("application_fee", strconv.FormatUint(params.Fee, 10))
	}

	if len(params.SourceType) > 0 {
		body.Add("source_type", string(params.SourceType))
	}
	params.AppendTo(body)

	transfer := &stripe.Transfer{}
	err := c.B.Call("POST", "/transfers", c.Key, body, &params.Params, transfer)

	return transfer, err
}

// Get returns the details of a transfer.
// For more details see https://stripe.com/docs/api#retrieve_transfer.
func Get(id string, params *stripe.TransferParams) (*stripe.Transfer, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.TransferParams) (*stripe.Transfer, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	transfer := &stripe.Transfer{}
	err := c.B.Call("GET", "/transfers/"+id, c.Key, body, commonParams, transfer)

	return transfer, err
}

// Update updates a transfer's properties.
// For more details see https://stripe.com/docs/api#update_transfer.
func Update(id string, params *stripe.TransferParams) (*stripe.Transfer, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.TransferParams) (*stripe.Transfer, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params

		body = &stripe.RequestValues{}

		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		params.AppendTo(body)
	}

	transfer := &stripe.Transfer{}
	err := c.B.Call("POST", "/transfers/"+id, c.Key, body, commonParams, transfer)

	return transfer, err
}

// Cancel cancels a pending transfer.
// For more details see https://stripe.com/docs/api#cancel_transfer.
func Cancel(id string, params *stripe.TransferParams) (*stripe.Transfer, error) {
	return getC().Cancel(id, params)
}

func (c Client) Cancel(id string, params *stripe.TransferParams) (*stripe.Transfer, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params

		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	transfer := &stripe.Transfer{}
	err := c.B.Call("POST", fmt.Sprintf("/transfers/%v/cancel", id), c.Key, body, commonParams, transfer)

	return transfer, err
}

// List returns a list of transfers.
// For more details see https://stripe.com/docs/api#list_transfers.
func List(params *stripe.TransferListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.TransferListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.Created > 0 {
			body.Add("created", strconv.FormatInt(params.Created, 10))
		}

		if params.Date > 0 {
			body.Add("date", strconv.FormatInt(params.Date, 10))
		}

		if len(params.Recipient) > 0 {
			body.Add("recipient", params.Recipient)
		}

		if len(params.Status) > 0 {
			body.Add("status", string(params.Status))
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.TransferList{}
		err := c.B.Call("GET", "/transfers", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Transfers.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Transfer returns the most recent Transfer
// visited by a call to Next.
func (i *Iter) Transfer() *stripe.Transfer {
	return i.Current().(*stripe.Transfer)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
