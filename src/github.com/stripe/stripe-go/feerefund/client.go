// Package feerefund provides the /application_fees/refunds APIs
package feerefund

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

// Client is used to invoke /application_fees/refunds APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New refunds the application fee collected.
// For more details see https://stripe.com/docs/api#refund_application_fee.
func New(params *stripe.FeeRefundParams) (*stripe.FeeRefund, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.FeeRefundParams) (*stripe.FeeRefund, error) {
	body := &stripe.RequestValues{}

	if params.Amount > 0 {
		body.Add("amount", strconv.FormatUint(params.Amount, 10))
	}

	params.AppendTo(body)

	refund := &stripe.FeeRefund{}
	err := c.B.Call("POST", fmt.Sprintf("application_fees/%v/refunds", params.Fee), c.Key, body, &params.Params, refund)

	return refund, err
}

// Get returns the details of a fee refund.
// For more details see https://stripe.com/docs/api#retrieve_fee_refund.
func Get(id string, params *stripe.FeeRefundParams) (*stripe.FeeRefund, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.FeeRefundParams) (*stripe.FeeRefund, error) {
	if params == nil {
		return nil, fmt.Errorf("params cannot be nil, and params.Fee must be set")
	}

	body := &stripe.RequestValues{}
	params.AppendTo(body)

	refund := &stripe.FeeRefund{}
	err := c.B.Call("GET", fmt.Sprintf("/application_fees/%v/refunds/%v", params.Fee, id), c.Key, body, &params.Params, refund)

	return refund, err
}

// Update updates a refund's properties.
// For more details see https://stripe.com/docs/api#update_refund.
func Update(id string, params *stripe.FeeRefundParams) (*stripe.FeeRefund, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.FeeRefundParams) (*stripe.FeeRefund, error) {
	body := &stripe.RequestValues{}
	params.AppendTo(body)

	refund := &stripe.FeeRefund{}
	err := c.B.Call("POST", fmt.Sprintf("/application_fees/%v/refunds/%v", params.Fee, id), c.Key, body, &params.Params, refund)

	return refund, err
}

// List returns a list of fee refunds.
// For more details see https://stripe.com/docs/api#list_fee_refunds.
func List(params *stripe.FeeRefundListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.FeeRefundListParams) *Iter {
	body := &stripe.RequestValues{}
	var lp *stripe.ListParams
	var p *stripe.Params

	params.AppendTo(body)
	lp = &params.ListParams
	p = params.ToParams()

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.FeeRefundList{}
		err := c.B.Call("GET", fmt.Sprintf("/application_fees/%v/refunds", params.Fee), c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of FeeRefunds.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// FeeRefund returns the most recent FeeRefund
// visited by a call to Next.
func (i *Iter) FeeRefund() *stripe.FeeRefund {
	return i.Current().(*stripe.FeeRefund)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
