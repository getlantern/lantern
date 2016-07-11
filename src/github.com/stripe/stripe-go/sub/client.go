// Package sub provides the /subscriptions APIs
package sub

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

const (
	Trialing stripe.SubStatus = "trialing"
	Active   stripe.SubStatus = "active"
	PastDue  stripe.SubStatus = "past_due"
	Canceled stripe.SubStatus = "canceled"
	Unpaid   stripe.SubStatus = "unpaid"
)

// Client is used to invoke /subscriptions APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTS a new subscription for a customer.
// For more details see https://stripe.com/docs/api#create_subscription.
func New(params *stripe.SubParams) (*stripe.Sub, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.SubParams) (*stripe.Sub, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params
	token := c.Key

	if params != nil {
		body = &stripe.RequestValues{}
		body.Add("plan", params.Plan)
		body.Add("customer", params.Customer)

		if len(params.Token) > 0 {
			body.Add("card", params.Token)
		} else if params.Card != nil {
			params.Card.AppendDetails(body, true)
		}

		if len(params.Coupon) > 0 {
			body.Add("coupon", params.Coupon)
		}

		if params.TrialEndNow {
			body.Add("trial_end", "now")
		} else if params.TrialEnd > 0 {
			body.Add("trial_end", strconv.FormatInt(params.TrialEnd, 10))
		}

		if params.TaxPercent > 0 {
			body.Add("tax_percent", strconv.FormatFloat(params.TaxPercent, 'f', 2, 64))
		} else if params.TaxPercentZero {
			body.Add("tax_percent", "0")
		}

		if params.Quantity > 0 {
			body.Add("quantity", strconv.FormatUint(params.Quantity, 10))
		} else if params.QuantityZero {
			body.Add("quantity", "0")
		}

		if params.FeePercent > 0 {
			body.Add("application_fee_percent", strconv.FormatFloat(params.FeePercent, 'f', 2, 64))
		}

		if params.BillingCycleAnchorNow {
			body.Add("billing_cycle_anchor", "now")
		} else if params.BillingCycleAnchor > 0 {
			body.Add("billing_cycle_anchor", strconv.FormatInt(params.BillingCycleAnchor, 10))
		}

		commonParams = &params.Params

		params.AppendTo(body)
	}

	sub := &stripe.Sub{}
	err := c.B.Call("POST", "/subscriptions", token, body, commonParams, sub)

	return sub, err
}

// Get returns the details of a subscription.
// For more details see https://stripe.com/docs/api#retrieve_subscription.
func Get(id string, params *stripe.SubParams) (*stripe.Sub, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.SubParams) (*stripe.Sub, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}
		params.AppendTo(body)
		commonParams = &params.Params
	}

	sub := &stripe.Sub{}
	err := c.B.Call("GET", fmt.Sprintf("/subscriptions/%v", id), c.Key, body, commonParams, sub)

	return sub, err
}

// Update updates a subscription's properties.
// For more details see https://stripe.com/docs/api#update_subscription.
func Update(id string, params *stripe.SubParams) (*stripe.Sub, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.SubParams) (*stripe.Sub, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params
	token := c.Key

	if params != nil {
		body = &stripe.RequestValues{}

		if len(params.Plan) > 0 {
			body.Add("plan", params.Plan)
		}

		if params.NoProrate {
			body.Add("prorate", strconv.FormatBool(false))
		}

		if len(params.Token) > 0 {
			body.Add("card", params.Token)
		} else if params.Card != nil {
			if len(params.Card.Token) > 0 {
				body.Add("card", params.Card.Token)
			} else {
				params.Card.AppendDetails(body, true)
			}
		}

		if len(params.Coupon) > 0 {
			body.Add("coupon", params.Coupon)
		}

		if params.TrialEndNow {
			body.Add("trial_end", "now")
		} else if params.TrialEnd > 0 {
			body.Add("trial_end", strconv.FormatInt(params.TrialEnd, 10))
		}

		if params.Quantity > 0 {
			body.Add("quantity", strconv.FormatUint(params.Quantity, 10))
		}

		if params.FeePercent > 0 {
			body.Add("application_fee_percent", strconv.FormatFloat(params.FeePercent, 'f', 2, 64))
		}

		if params.TaxPercent > 0 {
			body.Add("tax_percent", strconv.FormatFloat(params.TaxPercent, 'f', 2, 64))
		} else if params.TaxPercentZero {
			body.Add("tax_percent", "0")
		}

		if params.ProrationDate > 0 {
			body.Add("proration_date", strconv.FormatInt(params.ProrationDate, 10))
		}

		commonParams = &params.Params
		params.AppendTo(body)
	}

	sub := &stripe.Sub{}
	err := c.B.Call("POST", fmt.Sprintf("/subscriptions/%v", id), token, body, commonParams, sub)

	return sub, err
}

// Cancel removes a subscription.
// For more details see https://stripe.com/docs/api#cancel_subscription.
func Cancel(id string, params *stripe.SubParams) (*stripe.Sub, error) {
	return getC().Cancel(id, params)
}

func (c Client) Cancel(id string, params *stripe.SubParams) (*stripe.Sub, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.EndCancel {
			body.Add("at_period_end", strconv.FormatBool(true))
		}

		params.AppendTo(body)
		commonParams = &params.Params
	}

	sub := &stripe.Sub{}
	err := c.B.Call("DELETE", fmt.Sprintf("/subscriptions/%v", id), c.Key, body, commonParams, sub)

	return sub, err
}

// List returns a list of subscriptions.
// For more details see https://stripe.com/docs/api#list_subscriptions.
func List(params *stripe.SubListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.SubListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if len(params.Customer) > 0 {
			body.Add("customer", params.Customer)
		}

		if len(params.Plan) > 0 {
			body.Add("plan", params.Plan)
		}

		params.AppendTo(body)

		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.SubList{}
		err := c.B.Call("GET", "/subscriptions", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Subs.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Sub returns the most recent Sub
// visited by a call to Next.
func (i *Iter) Sub() *stripe.Sub {
	return i.Current().(*stripe.Sub)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
