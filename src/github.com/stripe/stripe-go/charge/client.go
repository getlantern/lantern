// Package charge provides the /charges APIs
package charge

import (
	"errors"
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

const (
	ReportFraudulent stripe.FraudReport = "fraudulent"
	ReportSafe       stripe.FraudReport = "safe"
)

// Client is used to invoke /charges APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs new charges.
// For more details see https://stripe.com/docs/api#create_charge.
func New(params *stripe.ChargeParams) (*stripe.Charge, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.ChargeParams) (*stripe.Charge, error) {
	body := &stripe.RequestValues{}
	body.Add("amount", strconv.FormatUint(params.Amount, 10))
	body.Add("currency", string(params.Currency))

	if params.Source == nil && len(params.Customer) == 0 {
		err := errors.New("Invalid charge params: either customer or a source must be set")
		return nil, err
	}

	if params.Source != nil {
		params.Source.AppendDetails(body, true)
	}

	if len(params.Customer) > 0 {
		body.Add("customer", params.Customer)
	}

	if len(params.Desc) > 0 {
		body.Add("description", params.Desc)
	}

	if len(params.Statement) > 0 {
		body.Add("statement_descriptor", params.Statement)
	}

	if len(params.Email) > 0 {
		body.Add("receipt_email", params.Email)
	}

	if len(params.Dest) > 0 {
		body.Add("destination", params.Dest)
	}

	body.Add("capture", strconv.FormatBool(!params.NoCapture))

	token := c.Key
	if params.Fee > 0 {
		body.Add("application_fee", strconv.FormatUint(params.Fee, 10))
	}

	if params.Shipping != nil {
		params.Shipping.AppendDetails(body)
	}

	params.AppendTo(body)

	charge := &stripe.Charge{}
	err := c.B.Call("POST", "/charges", token, body, &params.Params, charge)

	return charge, err
}

// Get returns the details of a charge.
// For more details see https://stripe.com/docs/api#retrieve_charge.
func Get(id string, params *stripe.ChargeParams) (*stripe.Charge, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.ChargeParams) (*stripe.Charge, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	charge := &stripe.Charge{}
	err := c.B.Call("GET", "/charges/"+id, c.Key, body, commonParams, charge)

	return charge, err
}

// Update updates a charge's properties.
// For more details see https://stripe.com/docs/api#update_charge.
func Update(id string, params *stripe.ChargeParams) (*stripe.Charge, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.ChargeParams) (*stripe.Charge, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}

		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		if len(params.Fraud) > 0 {
			body.Add("fraud_details[user_report]", string(params.Fraud))
		}

		params.AppendTo(body)
	}

	charge := &stripe.Charge{}
	err := c.B.Call("POST", "/charges/"+id, c.Key, body, commonParams, charge)

	return charge, err
}

// Capture captures a previously created charge with NoCapture set to true.
// For more details see https://stripe.com/docs/api#charge_capture.
func Capture(id string, params *stripe.CaptureParams) (*stripe.Charge, error) {
	return getC().Capture(id, params)
}

func (c Client) Capture(id string, params *stripe.CaptureParams) (*stripe.Charge, error) {
	var body *stripe.RequestValues
	token := c.Key
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}

		if params.Amount > 0 {
			body.Add("amount", strconv.FormatUint(params.Amount, 10))
		}

		if len(params.Email) > 0 {
			body.Add("receipt_email", params.Email)
		}

		if params.Fee > 0 {
			body.Add("application_fee", strconv.FormatUint(params.Fee, 10))
		}

		params.AppendTo(body)
	}

	charge := &stripe.Charge{}

	err := c.B.Call("POST", fmt.Sprintf("/charges/%v/capture", id), token, body, commonParams, charge)

	return charge, err
}

// List returns a list of charges.
// For more details see https://stripe.com/docs/api#list_charges.
func List(params *stripe.ChargeListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.ChargeListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.Created > 0 {
			body.Add("created", strconv.FormatInt(params.Created, 10))
		}

		if len(params.Customer) > 0 {
			body.Add("customer", params.Customer)
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.ChargeList{}
		err := c.B.Call("GET", "/charges", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// MarkFraudulent reports the charge as fraudulent.
func MarkFraudulent(id string) (*stripe.Charge, error) {
	return getC().MarkFraudulent(id)
}

func (c Client) MarkFraudulent(id string) (*stripe.Charge, error) {
	return c.Update(
		id,
		&stripe.ChargeParams{Fraud: ReportFraudulent})
}

// MarkSafe reports the charge as not-fraudulent.
func MarkSafe(id string) (*stripe.Charge, error) {
	return getC().MarkSafe(id)
}

func (c Client) MarkSafe(id string) (*stripe.Charge, error) {
	return c.Update(
		id,
		&stripe.ChargeParams{Fraud: ReportSafe})
}

// Update updates a charge's dispute.
// For more details see https://stripe.com/docs/api#update_dispute.
func UpdateDispute(id string, params *stripe.DisputeParams) (*stripe.Dispute, error) {
	return getC().UpdateDispute(id, params)
}

func (c Client) UpdateDispute(id string, params *stripe.DisputeParams) (*stripe.Dispute, error) {
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
	err := c.B.Call("POST", fmt.Sprintf("/charges/%v/dispute", id), c.Key, body, commonParams, dispute)

	return dispute, err
}

// Close dismisses a charge's dispute in the customer's favor.
// For more details see https://stripe.com/docs/api#close_dispute.
func CloseDispute(id string) (*stripe.Dispute, error) {
	return getC().CloseDispute(id)
}

func (c Client) CloseDispute(id string) (*stripe.Dispute, error) {
	dispute := &stripe.Dispute{}
	err := c.B.Call("POST", fmt.Sprintf("/charges/%v/dispute/close", id), c.Key, nil, nil, dispute)

	return dispute, err
}

// Iter is an iterator for lists of Charges.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Charge returns the most recent Charge
// visited by a call to Next.
func (i *Iter) Charge() *stripe.Charge {
	return i.Current().(*stripe.Charge)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
