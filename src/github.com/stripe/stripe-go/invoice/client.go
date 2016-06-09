// Package invoice provides the /invoices APIs
package invoice

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

const (
	TypeInvoiceItem  stripe.InvoiceLineType = "invoiceitem"
	TypeSubscription stripe.InvoiceLineType = "subscription"
)

// Client is the client used to invoke /invoices APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs new invoices.
// For more details see https://stripe.com/docs/api#create_invoice.
func New(params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	return getC().New(params)
}

func (c Client) New(params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	body := &stripe.RequestValues{}
	body.Add("customer", params.Customer)

	if len(params.Desc) > 0 {
		body.Add("description", params.Desc)
	}

	if len(params.Statement) > 0 {
		body.Add("statement_descriptor", params.Statement)
	}

	if len(params.Sub) > 0 {
		body.Add("subscription", params.Sub)
	}

	params.AppendTo(body)

	token := c.Key
	if params.Fee > 0 {
		body.Add("application_fee", strconv.FormatUint(params.Fee, 10))
	}

	if params.TaxPercent > 0 {
		body.Add("tax_percent", strconv.FormatFloat(params.TaxPercent, 'f', 2, 64))
	} else if params.TaxPercentZero {
		body.Add("tax_percent", "0")
	}

	invoice := &stripe.Invoice{}
	err := c.B.Call("POST", "/invoices", token, body, &params.Params, invoice)

	return invoice, err
}

// Get returns the details of an invoice.
// For more details see https://stripe.com/docs/api#retrieve_invoice.
func Get(id string, params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	invoice := &stripe.Invoice{}
	err := c.B.Call("GET", "/invoices/"+id, c.Key, body, commonParams, invoice)

	return invoice, err
}

// Pay pays an invoice.
// For more details see https://stripe.com/docs/api#pay_invoice.
func Pay(id string, params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	return getC().Pay(id, params)
}

func (c Client) Pay(id string, params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}

	invoice := &stripe.Invoice{}
	err := c.B.Call("POST", fmt.Sprintf("/invoices/%v/pay", id), c.Key, body, commonParams, invoice)

	return invoice, err
}

// Update updates an invoice's properties.
// For more details see https://stripe.com/docs/api#update_invoice.
func Update(id string, params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	return getC().Update(id, params)
}

func (c Client) Update(id string, params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	var body *stripe.RequestValues
	token := c.Key
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}

		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		if len(params.Statement) > 0 {
			body.Add("statement_descriptor", params.Statement)
		}

		if len(params.Sub) > 0 {
			body.Add("subscription", params.Sub)
		}

		if params.Closed {
			body.Add("closed", strconv.FormatBool(true))
		}

		if params.Forgive {
			body.Add("forgiven", strconv.FormatBool(true))
		}

		if params.Fee > 0 {
			body.Add("application_fee", strconv.FormatUint(params.Fee, 10))
		}

		if params.TaxPercent > 0 {
			body.Add("tax_percent", strconv.FormatFloat(params.TaxPercent, 'f', 2, 64))
		} else if params.TaxPercentZero {
			body.Add("tax_percent", "0")
		}

		params.AppendTo(body)
	}

	invoice := &stripe.Invoice{}
	err := c.B.Call("POST", "/invoices/"+id, token, body, commonParams, invoice)

	return invoice, err
}

// GetNext returns the upcoming invoice's properties.
// For more details see https://stripe.com/docs/api#retrieve_customer_invoice.
func GetNext(params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	return getC().GetNext(params)
}

func (c Client) GetNext(params *stripe.InvoiceParams) (*stripe.Invoice, error) {
	body := &stripe.RequestValues{}
	body.Add("customer", params.Customer)

	if len(params.Sub) > 0 {
		body.Add("subscription", params.Sub)
	}

	if len(params.SubPlan) > 0 {
		body.Add("subscription_plan", params.SubPlan)
	}

	if params.SubNoProrate {
		body.Add("subscription_prorate", strconv.FormatBool(false))
	}

	if params.SubProrationDate > 0 {
		body.Add("subscription_proration_date", strconv.FormatInt(params.SubProrationDate, 10))
	}

	if params.SubQuantity > 0 {
		body.Add("subscription_quantity", strconv.FormatUint(params.SubQuantity, 10))
	}

	if params.SubTrialEnd > 0 {
		body.Add("subscription_trial_end", strconv.FormatInt(params.SubTrialEnd, 10))
	}

	params.AppendTo(body)

	invoice := &stripe.Invoice{}
	err := c.B.Call("GET", "/invoices/upcoming", c.Key, body, &params.Params, invoice)

	return invoice, err
}

// List returns a list of invoices.
// For more details see https://stripe.com/docs/api#list_customer_invoices.
func List(params *stripe.InvoiceListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.InvoiceListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if len(params.Customer) > 0 {
			body.Add("customer", params.Customer)
		}

		if params.Date > 0 {
			body.Add("date", strconv.FormatInt(params.Date, 10))
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.InvoiceList{}
		err := c.B.Call("GET", "/invoices", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// ListLines returns a list of line items.
// For more details see https://stripe.com/docs/api#invoice_lines.
func ListLines(params *stripe.InvoiceLineListParams) *LineIter {
	return getC().ListLines(params)
}

func (c Client) ListLines(params *stripe.InvoiceLineListParams) *LineIter {
	body := &stripe.RequestValues{}
	var lp *stripe.ListParams
	var p *stripe.Params

	if len(params.Customer) > 0 {
		body.Add("customer", params.Customer)
	}

	if len(params.Sub) > 0 {
		body.Add("subscription", params.Sub)
	}

	params.AppendTo(body)
	lp = &params.ListParams
	p = params.ToParams()

	return &LineIter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.InvoiceLineList{}
		err := c.B.Call("GET", fmt.Sprintf("/invoices/%v/lines", params.ID), c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Invoices.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Invoice returns the most recent Invoice
// visited by a call to Next.
func (i *Iter) Invoice() *stripe.Invoice {
	return i.Current().(*stripe.Invoice)
}

// LineIter is an iterator for lists of InvoiceLines.
// The embedded Iter carries methods with it;
// see its documentation for details.
type LineIter struct {
	*stripe.Iter
}

// InvoiceLine returns the most recent InvoiceLine
// visited by a call to Next.
func (i *LineIter) InvoiceLine() *stripe.InvoiceLine {
	return i.Current().(*stripe.InvoiceLine)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
