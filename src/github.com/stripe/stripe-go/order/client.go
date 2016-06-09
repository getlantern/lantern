package order

import (
	"errors"
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

// Client is used to invoke /orders APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs a new order.
// For more details see https://stripe.com/docs/api#create_order.
func New(params *stripe.OrderParams) (*stripe.Order, error) {
	return getC().New(params)
}

// New POSTs a new order.
// For more details see https://stripe.com/docs/api#create_order.
func (c Client) New(params *stripe.OrderParams) (*stripe.Order, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}
		commonParams = &params.Params
		// Required fields
		body.Add("currency", string(params.Currency))

		if params.Customer != "" {
			body.Add("customer", params.Customer)
		}

		if params.Email != "" {
			body.Add("email", params.Email)
		}

		if len(params.Items) > 0 {
			for _, item := range params.Items {
				body.Add("items[][description]", item.Description)
				body.Add("items[][type]", string(item.Type))
				body.Add("items[][amount]", strconv.FormatInt(item.Amount, 10))
				if item.Currency != "" {
					body.Add("items[][currency]", string(item.Currency))
				}
				if item.Parent != "" {
					body.Add("items[][parent]", item.Parent)
				}
				if item.Quantity != nil {
					body.Add("items[][quantity]", strconv.FormatInt(*item.Quantity, 10))
				}
			}
		}

		if params.Shipping != nil {
			if params.Shipping.Address != nil {
				body.Add("shipping[address][line1]", params.Shipping.Address.Line1)
				if params.Shipping.Address.Line2 != "" {
					body.Add("shipping[address][line2]", params.Shipping.Address.Line2)
				}
				if params.Shipping.Address.City != "" {
					body.Add("shipping[address][city]", params.Shipping.Address.City)
				}
				if params.Shipping.Address.Country != "" {
					body.Add("shipping[address][country]", params.Shipping.Address.Country)
				}
				if params.Shipping.Address.PostalCode != "" {
					body.Add("shipping[address][postal_code]", params.Shipping.Address.PostalCode)
				}
				if params.Shipping.Address.State != "" {
					body.Add("shipping[address][state]", params.Shipping.Address.State)
				}
			}

			if params.Shipping.Name != "" {
				body.Add("shipping[name]", params.Shipping.Name)
			}
			if params.Shipping.Phone != "" {
				body.Add("shipping[phone]", params.Shipping.Phone)
			}
		}

		params.AppendTo(body)
	}

	p := &stripe.Order{}
	err := c.B.Call("POST", "/orders", c.Key, body, commonParams, p)

	return p, err
}

// Update updates an order's properties.
// For more details see https://stripe.com/docs/api#update_order.
func Update(id string, params *stripe.OrderUpdateParams) (*stripe.Order, error) {
	return getC().Update(id, params)
}

// Update updates an order's properties.
// For more details see https://stripe.com/docs/api#update_order.
func (c Client) Update(id string, params *stripe.OrderUpdateParams) (*stripe.Order, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.Coupon != "" {
			body.Add("coupon", params.Coupon)
		}

		if params.SelectedShippingMethod != "" {
			body.Add("selected_shipping_method", params.SelectedShippingMethod)
		}

		if params.Status != "" {
			body.Add("status", string(params.Status))
		}

		params.AppendTo(body)
	}

	o := &stripe.Order{}
	err := c.B.Call("POST", "/orders/"+id, c.Key, body, commonParams, o)

	return o, err
}

// Pay pays an order
// For more details see https://stripe.com/docs/api#pay_order.
func Pay(id string, params *stripe.OrderPayParams) (*stripe.Order, error) {
	return getC().Pay(id, params)
}

// Pay pays an order
// For more details see https://stripe.com/docs/api#pay_order.
func (c Client) Pay(id string, params *stripe.OrderPayParams) (*stripe.Order, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}
		commonParams = &params.Params
		if params.Source == nil && len(params.Customer) == 0 {
			err := errors.New("Invalid order pay params: either customer or a source must be set")
			return nil, err
		}
		// We can't use `AppendDetails` since that nests under `card`.
		if params.Source != nil {
			if len(params.Source.Token) > 0 {
				body.Add("source", params.Source.Token)
			} else if params.Source.Card != nil {
				c := params.Source.Card

				body.Add("source[object]", "card")
				body.Add("source[number]", c.Number)
				body.Add("source[exp_month]", c.Month)
				body.Add("source[exp_year]", c.Year)

				if len(c.CVC) > 0 {
					body.Add("source[cvc]", c.CVC)
				}

				body.Add("source[name]", c.Name)

				if len(c.Address1) > 0 {
					body.Add("source[address_line1]", c.Address1)
				}

				if len(c.Address2) > 0 {
					body.Add("source[address_line2]", c.Address2)
				}
				if len(c.City) > 0 {
					body.Add("source[address_city]", c.City)
				}

				if len(c.State) > 0 {
					body.Add("source[address_state]", c.State)
				}
				if len(c.Zip) > 0 {
					body.Add("source[address_zip]", c.Zip)
				}
				if len(c.Country) > 0 {
					body.Add("source[address_country]", c.Country)
				}
			}
		}

		if len(params.Customer) > 0 {
			body.Add("customer", params.Customer)
		}

		if params.ApplicationFee > 0 {
			body.Add("application_fee", strconv.FormatInt(params.ApplicationFee, 10))
		}

		if params.Email != "" {
			body.Add("email", params.Email)
		}

		params.AppendTo(body)
	}

	o := &stripe.Order{}
	err := c.B.Call("POST", "/orders/"+id+"/pay", c.Key, body, commonParams, o)

	return o, err
}

// Get returns the details of an order
// For more details see https://stripe.com/docs/api#retrieve_order.
func Get(id string, params *stripe.OrderParams) (*stripe.Order, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.OrderParams) (*stripe.Order, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}
		commonParams = &params.Params
		params.AppendTo(body)
	}

	order := &stripe.Order{}
	err := c.B.Call("GET", "/orders/"+id, c.Key, body, commonParams, order)
	return order, err
}

// List returns a list of orders.
// For more details see https://stripe.com/docs/api#list_orders
func List(params *stripe.OrderListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.OrderListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		for _, id := range params.IDs {
			params.Filters.AddFilter("ids[]", "", id)
		}

		if params.Status != "" {
			params.Filters.AddFilter("status", "", string(params.Status))
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.OrderList{}
		err := c.B.Call("GET", "/orders", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Orders.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Order returns the most recent Order
// visited by a call to Next.
func (i *Iter) Order() *stripe.Order {
	return i.Current().(*stripe.Order)
}

// Return returns all or part of an order.
// For more details see https://stripe.com/docs/api#return_order.
func Return(id string, params *stripe.OrderReturnParams) (*stripe.OrderReturn, error) {
	return getC().Return(id, params)
}

// Return returns all or part of an order.
// For more details see https://stripe.com/docs/api#return_order.
func (c Client) Return(id string, params *stripe.OrderReturnParams) (*stripe.OrderReturn, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if len(params.Items) > 0 {
			for _, item := range params.Items {
				if item.Description != "" {
					body.Add("items[][description]", item.Description)
				}
				body.Add("items[][type]", string(item.Type))
				if item.Amount > 0 {
					body.Add("items[][amount]", strconv.FormatInt(item.Amount, 10))
				}
				if item.Currency != "" {
					body.Add("items[][currency]", string(item.Currency))
				}
				if item.Parent != "" {
					body.Add("items[][parent]", item.Parent)
				}
				if item.Quantity != nil {
					body.Add("items[][quantity]", strconv.FormatInt(*item.Quantity, 10))
				}
			}
		}

		params.AppendTo(body)
	}

	ret := &stripe.OrderReturn{}
	err := c.B.Call("POST", fmt.Sprintf("/orders/%s/returns", id), c.Key, body, commonParams, ret)

	return ret, err
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
