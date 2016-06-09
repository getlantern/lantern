// Package refund provides the /refunds APIs
package refund

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

const (
	RefundFraudulent          stripe.RefundReason = "fraudulent"
	RefundDuplicate           stripe.RefundReason = "duplicate"
	RefundRequestedByCustomer stripe.RefundReason = "requested_by_customer"
)

// Client is used to invoke /refunds APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New refunds a charge previously created.
// For more details see https://stripe.com/docs/api#refund_charge.
func New(params *stripe.RefundParams) (*stripe.Refund, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.RefundParams) (*stripe.Refund, error) {
	body := &stripe.RequestValues{}

	if params.Amount > 0 {
		body.Add("amount", strconv.FormatUint(params.Amount, 10))
	}

	if params.Fee {
		body.Add("refund_application_fee", strconv.FormatBool(params.Fee))
	}

	if params.Transfer {
		body.Add("reverse_transfer", strconv.FormatBool(params.Transfer))
	}

	if len(params.Reason) > 0 {
		body.Add("reason", string(params.Reason))
	}

	if len(params.Charge) > 0 {
		body.Add("charge", string(params.Charge))
	}

	params.AppendTo(body)

	refund := &stripe.Refund{}
	err := c.B.Call("POST", fmt.Sprintf("/refunds"), c.Key, body, &params.Params, refund)

	return refund, err
}

// Get returns the details of a refund.
// For more details see https://stripe.com/docs/api#retrieve_refund.
func Get(id string, params *stripe.RefundParams) (*stripe.Refund, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.RefundParams) (*stripe.Refund, error) {
	body := &stripe.RequestValues{}
	params.AppendTo(body)

	refund := &stripe.Refund{}
	err := c.B.Call("GET", fmt.Sprintf("/refunds/%v", id), c.Key, body, &params.Params, refund)

	return refund, err
}

// Update updates a refund's properties.
// For more details see https://stripe.com/docs/api#update_refund.
func Update(id string, params *stripe.RefundParams) (*stripe.Refund, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.RefundParams) (*stripe.Refund, error) {
	body := &stripe.RequestValues{}

	params.AppendTo(body)

	refund := &stripe.Refund{}
	err := c.B.Call("POST", fmt.Sprintf("/refunds/%v", id), c.Key, body, &params.Params, refund)

	return refund, err
}

// List returns a list of refunds.
// For more details see https://stripe.com/docs/api#list_refunds.
func List(params *stripe.RefundListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.RefundListParams) *Iter {
	body := &stripe.RequestValues{}
	var lp *stripe.ListParams
	var p *stripe.Params

	params.AppendTo(body)
	lp = &params.ListParams
	p = params.ToParams()

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.RefundList{}
		err := c.B.Call("GET", fmt.Sprintf("/refunds"), c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Refunds.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Refund returns the most recent Refund
// visited by a call to Next.
func (i *Iter) Refund() *stripe.Refund {
	return i.Current().(*stripe.Refund)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
