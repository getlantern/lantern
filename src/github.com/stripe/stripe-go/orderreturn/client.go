package orderreturn

import (
	"github.com/stripe/stripe-go"
)

// Client is used to invoke /orders APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// For more details see https://stripe.com/docs/api#list_orders
func List(params *stripe.OrderReturnListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.OrderReturnListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.Order != "" {
			params.Filters.AddFilter("order", "", params.Order)
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.OrderReturnList{}
		err := c.B.Call("GET", "/order_returns", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of OrderReturns.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// OrderReturn returns the most recent OrderReturn
// visited by a call to Next.
func (i *Iter) OrderReturn() *stripe.OrderReturn {
	return i.Current().(*stripe.OrderReturn)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
