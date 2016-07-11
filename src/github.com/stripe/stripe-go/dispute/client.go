// Package dispute provides the dispute-related APIs
package dispute

import (
	"fmt"

	stripe "github.com/stripe/stripe-go"
)

const (
	Duplicate    stripe.DisputeReason = "duplicate"
	Fraudulent   stripe.DisputeReason = "fraudulent"
	SubCanceled  stripe.DisputeReason = "subscription_canceled"
	Unacceptable stripe.DisputeReason = "product_unacceptable"
	NotReceived  stripe.DisputeReason = "product_not_received"
	Unrecognized stripe.DisputeReason = "unrecognized"
	Credit       stripe.DisputeReason = "credit_not_processed"
	General      stripe.DisputeReason = "general"

	Won             stripe.DisputeStatus = "won"
	Lost            stripe.DisputeStatus = "lost"
	Response        stripe.DisputeStatus = "needs_response"
	Review          stripe.DisputeStatus = "under_review"
	WarningResponse stripe.DisputeStatus = "warning_needs_response"
	WarningReview   stripe.DisputeStatus = "warning_under_review"
	ChargeRefunded  stripe.DisputeStatus = "charge_refunded"
	WarningClosed   stripe.DisputeStatus = "warning_closed"
)

// Client is used to invoke dispute-related APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// Get returns the details of a dispute.
// For more details see https://stripe.com/docs/api#retrieve_dispute.
func Get(id string, params *stripe.DisputeParams) (*stripe.Dispute, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.DisputeParams) (*stripe.Dispute, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	dispute := &stripe.Dispute{}
	err := c.B.Call("GET", "/disputes/"+id, c.Key, body, commonParams, dispute)

	return dispute, err
}

// List returns a list of disputes.
// For more details see https://stripe.com/docs/api#list_disputes.
func List(params *stripe.DisputeListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.DisputeListParams) *Iter {
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
		list := &stripe.DisputeList{}
		err := c.B.Call("GET", "/disputes", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Disputes.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Dispute returns the most recent Dispute
// visited by a call to Next.
func (i *Iter) Dispute() *stripe.Dispute {
	return i.Current().(*stripe.Dispute)
}

// Update updates a dispute.
// For more details see https://stripe.com/docs/api#update_dispute.
func Update(id string, params *stripe.DisputeParams) (*stripe.Dispute, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.DisputeParams) (*stripe.Dispute, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}

		if params.Evidence != nil {
			params.Evidence.AppendDetails(body)
		}
		params.AppendTo(body)
	}

	dispute := &stripe.Dispute{}
	err := c.B.Call("POST", fmt.Sprintf("/disputes/%v", id), c.Key, body, commonParams, dispute)

	return dispute, err
}

// Close dismisses a dispute in the customer's favor.
// For more details see https://stripe.com/docs/api#close_dispute.
func Close(id string) (*stripe.Dispute, error) {
	return getC().Close(id)
}

func (c Client) Close(id string) (*stripe.Dispute, error) {
	dispute := &stripe.Dispute{}
	err := c.B.Call("POST", fmt.Sprintf("/disputes/%v/close", id), c.Key, nil, nil, dispute)

	return dispute, err
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
