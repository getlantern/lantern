// Package reversal provides the /transfers/reversals APIs
package reversal

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

// Client is used to invoke /transfers/reversals APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs a new transfer reversal.
func New(params *stripe.ReversalParams) (*stripe.Reversal, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.ReversalParams) (*stripe.Reversal, error) {
	body := &stripe.RequestValues{}

	if params.Amount > 0 {
		body.Add("amount", strconv.FormatUint(params.Amount, 10))
	}

	if params.Fee {
		body.Add("refund_application_fee", strconv.FormatBool(params.Fee))
	}

	params.AppendTo(body)

	reversal := &stripe.Reversal{}
	err := c.B.Call("POST", fmt.Sprintf("/transfers/%v/reversals", params.Transfer), c.Key, body, &params.Params, reversal)

	return reversal, err
}

// Get returns the details of a transfer reversal.
func Get(id string, params *stripe.ReversalParams) (*stripe.Reversal, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.ReversalParams) (*stripe.Reversal, error) {
	if params == nil {
		return nil, fmt.Errorf("params cannot be nil, and params.Transfer must be set")
	}

	body := &stripe.RequestValues{}
	params.AppendTo(body)

	reversal := &stripe.Reversal{}
	err := c.B.Call("GET", fmt.Sprintf("/transfers/%v/reversals/%v", params.Transfer, id), c.Key, body, &params.Params, reversal)

	return reversal, err
}

// Update updates a transfer reversal's properties.
func Update(id string, params *stripe.ReversalParams) (*stripe.Reversal, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.ReversalParams) (*stripe.Reversal, error) {
	body := &stripe.RequestValues{}

	params.AppendTo(body)

	reversal := &stripe.Reversal{}
	err := c.B.Call("POST", fmt.Sprintf("/transfers/%v/reversals/%v", params.Transfer, id), c.Key, body, &params.Params, reversal)

	return reversal, err
}

// List returns a list of transfer reversals.
func List(params *stripe.ReversalListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.ReversalListParams) *Iter {
	body := &stripe.RequestValues{}
	var lp *stripe.ListParams
	var p *stripe.Params

	params.AppendTo(body)
	lp = &params.ListParams
	p = params.ToParams()

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.ReversalList{}
		err := c.B.Call("GET", fmt.Sprintf("/transfers/%v/reversals", params.Transfer), c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Reversals.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Refund returns the most recent Reversals
// visited by a call to Next.
func (i *Iter) Reversal() *stripe.Reversal {
	return i.Current().(*stripe.Reversal)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
